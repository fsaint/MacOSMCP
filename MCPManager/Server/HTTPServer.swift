import Foundation
import Network
import os

/// A minimal HTTP/1.1 server using Network.framework, bound to localhost only.
actor HTTPServer {
    private let port: UInt16
    private var listener: NWListener?
    private let logger = Logger(subsystem: "com.mcpmanager.app", category: "HTTPServer")
    private var requestHandler: (@Sendable (HTTPRequest) async -> HTTPResponse)?

    private(set) var isRunning = false
    var onClientConnected: (@Sendable (String) -> Void)?
    var onClientDisconnected: (@Sendable (String) -> Void)?

    init(port: UInt16 = 9200) {
        self.port = port
    }

    func start(handler: @escaping @Sendable (HTTPRequest) async -> HTTPResponse) throws {
        self.requestHandler = handler

        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        params.acceptLocalOnly = true

        let listener = try NWListener(using: params)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleListenerState(state)
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task { [weak self] in
                await self?.handleConnection(connection)
            }
        }

        listener.start(queue: .global(qos: .userInitiated))
        isRunning = true
        logger.info("MCP server starting on 127.0.0.1:\(self.port)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        logger.info("MCP server stopped")
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("Server listening on 127.0.0.1:\(self.port)")
        case .failed(let error):
            logger.error("Server failed: \(error.localizedDescription)")
            isRunning = false
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        let clientId = connection.endpoint.debugDescription
        logger.debug("New connection from \(clientId)")
        onClientConnected?(clientId)

        connection.start(queue: .global(qos: .userInitiated))

        Task {
            await receiveRequest(on: connection, clientId: clientId)
        }
    }

    private func receiveRequest(on connection: NWConnection, clientId: String) async {
        let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            receiveFullRequest(on: connection, buffer: Data()) { data in
                continuation.resume(returning: data)
            }
        }

        guard let data,
              let request = HTTPRequest.parse(from: data) else {
            let response = HTTPResponse.badRequest("Malformed HTTP request")
            sendResponse(response, on: connection, clientId: clientId)
            return
        }

        guard let handler = requestHandler else {
            let response = HTTPResponse.internalServerError()
            sendResponse(response, on: connection, clientId: clientId)
            return
        }

        let response = await handler(request)
        sendResponse(response, on: connection, clientId: clientId)
    }

    private func receiveFullRequest(on connection: NWConnection, buffer: Data, completion: @escaping @Sendable (Data?) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else {
                completion(nil)
                return
            }

            if let error {
                self.logger.error("Receive error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            var buffer = buffer
            if let content {
                buffer.append(content)
            }

            // Check if we have a complete HTTP request
            if HTTPRequest.parse(from: buffer) != nil {
                completion(buffer)
            } else if isComplete {
                completion(buffer.isEmpty ? nil : buffer)
            } else {
                // Need more data
                self.receiveFullRequest(on: connection, buffer: buffer, completion: completion)
            }
        }
    }

    private nonisolated func sendResponse(_ response: HTTPResponse, on connection: NWConnection, clientId: String) {
        let data = response.serialize()
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                Task { await self?.logger.error("Send error: \(error.localizedDescription)") }
            }
            connection.cancel()
            Task { await self?.onClientDisconnected?(clientId) }
        })
    }
}
