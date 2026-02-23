import Foundation
import os

/// Routes incoming MCP JSON-RPC requests to the appropriate handler.
actor MCPRequestRouter {
    private let sessionStore = MCPSessionStore()
    private let toolRegistry: ToolRegistry
    private let activityLogger: ActivityLogger
    private let logger = Logger(subsystem: "com.mcpmanager.app", category: "MCPRouter")

    private let protocolVersion = "2025-03-26"
    private let serverInfo = MCPImplementation(name: "apple-music-mcp", version: "1.0.0")
    private let bearerToken: String

    init(toolRegistry: ToolRegistry, activityLogger: ActivityLogger, bearerToken: String) {
        self.toolRegistry = toolRegistry
        self.activityLogger = activityLogger
        self.bearerToken = bearerToken
    }

    /// Handle an incoming HTTP request and return an HTTP response.
    func handle(_ httpRequest: HTTPRequest) async -> HTTPResponse {
        // Only accept POST /mcp
        guard httpRequest.path == "/mcp" || httpRequest.path == "/mcp/" else {
            return .notFound()
        }

        guard httpRequest.method == "POST" else {
            return .methodNotAllowed()
        }

        // Validate bearer token
        guard httpRequest.bearerToken == bearerToken else {
            await activityLogger.log("Rejected: invalid or missing auth token")
            return .unauthorized()
        }

        // Parse JSON-RPC request
        let rpcRequest: JSONRPCRequest
        do {
            rpcRequest = try JSONRPCCoder.decodeRequest(from: httpRequest.body)
        } catch {
            logger.error("Failed to parse JSON-RPC: \(error.localizedDescription)")
            let errorResp = JSONRPCResponse.error(id: nil, code: JSONRPCErrorCode.parseError, message: "Parse error")
            return jsonResponse(errorResp)
        }

        // Route based on method
        switch rpcRequest.method {
        case "initialize":
            return await handleInitialize(rpcRequest)
        case "notifications/initialized":
            return .accepted()
        case "tools/list":
            return await handleToolsList(rpcRequest, sessionId: httpRequest.sessionId)
        case "tools/call":
            return await handleToolsCall(rpcRequest, sessionId: httpRequest.sessionId)
        case "ping":
            return handlePing(rpcRequest)
        default:
            logger.warning("Unknown method: \(rpcRequest.method)")
            let errorResp = JSONRPCResponse.error(
                id: rpcRequest.id,
                code: JSONRPCErrorCode.methodNotFound,
                message: "Method not found: \(rpcRequest.method)"
            )
            return jsonResponse(errorResp)
        }
    }

    // MARK: - Initialize

    private func handleInitialize(_ request: JSONRPCRequest) async -> HTTPResponse {
        // Parse client info from params
        let clientInfo: MCPImplementation
        if let params = request.params?.dictValue,
           let info = params["clientInfo"] as? [String: Any],
           let name = info["name"] as? String,
           let version = info["version"] as? String {
            clientInfo = MCPImplementation(name: name, version: version)
        } else {
            clientInfo = MCPImplementation(name: "unknown", version: "0.0.0")
        }

        let session = await sessionStore.create(clientInfo: clientInfo)
        logger.info("New session \(session.id) for client \(clientInfo.name)")
        await activityLogger.log("Client connected: \(clientInfo.name) v\(clientInfo.version)")

        let result = MCPInitializeResult(
            protocolVersion: protocolVersion,
            capabilities: MCPServerCapabilities(
                tools: MCPToolsCapability(listChanged: false),
                resources: nil,
                prompts: nil,
                logging: nil
            ),
            serverInfo: serverInfo,
            instructions: "Apple Music MCP Server. Use tools to search Apple Music, browse your library, and manage playlists."
        )

        // Encode result to dictionary for AnyCodable
        let resultDict = encodeToDictionary(result)
        let rpcResponse = JSONRPCResponse.success(id: request.id, result: resultDict)
        return jsonResponse(rpcResponse, extraHeaders: ["Mcp-Session-Id": session.id])
    }

    // MARK: - Tools List

    private func handleToolsList(_ request: JSONRPCRequest, sessionId: String?) async -> HTTPResponse {
        if let sessionId, await sessionStore.get(sessionId) == nil {
            return .notFound()
        }

        let tools = await toolRegistry.listTools()
        let result = ["tools": tools.map { encodeToDictionary($0) }]
        let rpcResponse = JSONRPCResponse.success(id: request.id, result: result)

        var headers: [String: String] = [:]
        if let sessionId { headers["Mcp-Session-Id"] = sessionId }
        return jsonResponse(rpcResponse, extraHeaders: headers)
    }

    // MARK: - Tools Call

    private func handleToolsCall(_ request: JSONRPCRequest, sessionId: String?) async -> HTTPResponse {
        if let sessionId, await sessionStore.get(sessionId) == nil {
            return .notFound()
        }

        guard let toolCall = MCPToolCallParams(from: request.params) else {
            let errorResp = JSONRPCResponse.error(
                id: request.id,
                code: JSONRPCErrorCode.invalidParams,
                message: "Missing or invalid tool name"
            )
            return jsonResponse(errorResp)
        }

        logger.info("Tool call: \(toolCall.name)")
        await activityLogger.log("Tool call: \(toolCall.name)")

        let result = await toolRegistry.call(name: toolCall.name, arguments: toolCall.arguments)

        // Encode MCPToolCallResult manually
        let contentArray: [[String: Any]] = result.content.map { content in
            switch content {
            case .text(let text):
                return ["type": "text", "text": text]
            }
        }
        var resultDict: [String: Any] = ["content": contentArray]
        if let isError = result.isError {
            resultDict["isError"] = isError
        }

        let rpcResponse = JSONRPCResponse.success(id: request.id, result: resultDict)
        var headers: [String: String] = [:]
        if let sessionId { headers["Mcp-Session-Id"] = sessionId }
        return jsonResponse(rpcResponse, extraHeaders: headers)
    }

    // MARK: - Ping

    private func handlePing(_ request: JSONRPCRequest) -> HTTPResponse {
        let rpcResponse = JSONRPCResponse.success(id: request.id, result: [String: Any]())
        return jsonResponse(rpcResponse)
    }

    // MARK: - Helpers

    private func jsonResponse(_ response: JSONRPCResponse, extraHeaders: [String: String] = [:]) -> HTTPResponse {
        do {
            let data = try JSONRPCCoder.encodeResponse(response)
            return .json(data, extraHeaders: extraHeaders)
        } catch {
            logger.error("Failed to encode response: \(error.localizedDescription)")
            return .internalServerError()
        }
    }

    private func encodeToDictionary<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    // MARK: - Session Info

    func activeSessionCount() async -> Int {
        await sessionStore.count
    }

    func activeSessions() async -> [MCPSession] {
        await sessionStore.activeSessions
    }
}
