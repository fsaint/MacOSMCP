import Foundation

/// Helpers for encoding/decoding JSON-RPC 2.0 messages.
enum JSONRPCCoder {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        JSONDecoder()
    }()

    // MARK: - Encoding (Client)

    static func encode(_ request: JSONRPCRequest) throws -> Data {
        try encoder.encode(request)
    }

    static func encodeRequest(
        id: Int,
        method: String,
        params: [String: Any]? = nil
    ) throws -> Data {
        let rpcParams = params.map { AnyCodable($0) }
        let request = JSONRPCRequest(id: .int(id), method: method, params: rpcParams)
        return try encode(request)
    }

    static func encodeNotification(method: String, params: [String: Any]? = nil) throws -> Data {
        let rpcParams = params.map { AnyCodable($0) }
        let request = JSONRPCRequest(id: nil, method: method, params: rpcParams)
        return try encode(request)
    }

    // MARK: - Encoding (Server)

    static func encodeResponse(_ response: JSONRPCResponse) throws -> Data {
        try encoder.encode(response)
    }

    static func encodeSuccessResponse(id: JSONRPCId?, result: Any) throws -> Data {
        try encodeResponse(.success(id: id, result: result))
    }

    static func encodeErrorResponse(id: JSONRPCId?, code: Int, message: String, data: Any? = nil) throws -> Data {
        try encodeResponse(.error(id: id, code: code, message: message, data: data))
    }

    // MARK: - Decoding

    static func decodeRequest(from data: Data) throws -> JSONRPCRequest {
        try decoder.decode(JSONRPCRequest.self, from: data)
    }

    static func decodeResponse(from data: Data) throws -> JSONRPCResponse {
        try decoder.decode(JSONRPCResponse.self, from: data)
    }

    static func decodeResult<T: Decodable>(_ type: T.Type, from response: JSONRPCResponse) throws -> T {
        guard let result = response.result else {
            if let error = response.error {
                throw MCPError.jsonRPCError(code: error.code, message: error.message)
            }
            throw MCPError.emptyResult
        }
        let data = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func decodeResult<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let response = try decodeResponse(from: data)
        return try decodeResult(type, from: response)
    }
}

// MARK: - MCP Errors

enum MCPError: LocalizedError {
    case jsonRPCError(code: Int, message: String)
    case emptyResult
    case invalidURL(String)
    case connectionFailed(String)
    case unauthorized
    case sessionExpired
    case timeout
    case serverDisconnected
    case invalidRequest(String)
    case methodNotFound(String)

    var errorDescription: String? {
        switch self {
        case .jsonRPCError(let code, let message): return "JSON-RPC error \(code): \(message)"
        case .emptyResult: return "Empty result in response"
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .connectionFailed(let reason): return "Connection failed: \(reason)"
        case .unauthorized: return "Unauthorized — authentication required"
        case .sessionExpired: return "Session expired"
        case .timeout: return "Request timed out"
        case .serverDisconnected: return "Server disconnected"
        case .invalidRequest(let reason): return "Invalid request: \(reason)"
        case .methodNotFound(let method): return "Method not found: \(method)"
        }
    }
}
