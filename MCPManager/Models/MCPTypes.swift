import Foundation

// MARK: - JSON-RPC 2.0

struct JSONRPCRequest: Codable, Sendable {
    let jsonrpc: String
    let id: JSONRPCId?
    let method: String
    let params: AnyCodable?

    init(id: JSONRPCId? = nil, method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }

    var isNotification: Bool { id == nil }
}

struct JSONRPCResponse: Codable, Sendable {
    let jsonrpc: String
    let id: JSONRPCId?
    let result: AnyCodable?
    let error: JSONRPCError?

    static func success(id: JSONRPCId?, result: Any) -> JSONRPCResponse {
        JSONRPCResponse(jsonrpc: "2.0", id: id, result: AnyCodable(result), error: nil)
    }

    static func error(id: JSONRPCId?, code: Int, message: String, data: Any? = nil) -> JSONRPCResponse {
        JSONRPCResponse(
            jsonrpc: "2.0",
            id: id,
            result: nil,
            error: JSONRPCError(code: code, message: message, data: data.map { AnyCodable($0) })
        )
    }
}

struct JSONRPCError: Codable, Sendable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

enum JSONRPCId: Codable, Equatable, Sendable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(
                JSONRPCId.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

// MARK: - JSON-RPC Error Codes

enum JSONRPCErrorCode {
    static let parseError = -32700
    static let invalidRequest = -32600
    static let methodNotFound = -32601
    static let invalidParams = -32602
    static let internalError = -32603
}

// MARK: - MCP Protocol Types

struct MCPInitializeParams: Codable, Sendable {
    let protocolVersion: String
    let capabilities: MCPClientCapabilities
    let clientInfo: MCPImplementation
}

struct MCPClientCapabilities: Codable, Sendable {
    let roots: MCPRootsCapability?
    let sampling: AnyCodable?

    init(roots: MCPRootsCapability? = nil, sampling: AnyCodable? = nil) {
        self.roots = roots
        self.sampling = sampling
    }
}

struct MCPRootsCapability: Codable, Sendable {
    let listChanged: Bool?
}

struct MCPImplementation: Codable, Sendable {
    let name: String
    let version: String
}

struct MCPInitializeResult: Codable, Sendable {
    let protocolVersion: String
    let capabilities: MCPServerCapabilities
    let serverInfo: MCPImplementation
    let instructions: String?
}

struct MCPServerCapabilities: Codable, Sendable {
    let tools: MCPToolsCapability?
    let resources: MCPResourcesCapability?
    let prompts: MCPPromptsCapability?
    let logging: AnyCodable?
}

struct MCPToolsCapability: Codable, Sendable {
    let listChanged: Bool?
}

struct MCPResourcesCapability: Codable, Sendable {
    let subscribe: Bool?
    let listChanged: Bool?
}

struct MCPPromptsCapability: Codable, Sendable {
    let listChanged: Bool?
}

// MARK: - MCP Tools

struct MCPTool: Codable, Identifiable, Sendable {
    let name: String
    let description: String?
    let inputSchema: AnyCodable?

    var id: String { name }
}

struct MCPToolsListResult: Codable, Sendable {
    let tools: [MCPTool]
}

// MARK: - MCP Tool Call Types

struct MCPToolCallParams: Sendable {
    let name: String
    let arguments: [String: Any]

    init?(from params: AnyCodable?) {
        guard let dict = params?.dictValue,
              let name = dict["name"] as? String else { return nil }
        self.name = name
        self.arguments = (dict["arguments"] as? [String: Any]) ?? [:]
    }
}

struct MCPToolCallResult: Codable, Sendable {
    let content: [MCPContent]
    let isError: Bool?

    init(content: [MCPContent], isError: Bool? = nil) {
        self.content = content
        self.isError = isError
    }

    static func text(_ text: String) -> MCPToolCallResult {
        MCPToolCallResult(content: [.text(text)])
    }

    static func error(_ message: String) -> MCPToolCallResult {
        MCPToolCallResult(content: [.text(message)], isError: true)
    }
}

enum MCPContent: Codable, Sendable {
    case text(String)

    var type: String {
        switch self {
        case .text: return "text"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, text
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .text)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }
}
