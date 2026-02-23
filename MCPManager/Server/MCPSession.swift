import Foundation

/// Represents a single MCP client session.
final class MCPSession: Sendable {
    let id: String
    let clientInfo: MCPImplementation
    let createdAt: Date

    init(clientInfo: MCPImplementation) {
        self.id = UUID().uuidString
        self.clientInfo = clientInfo
        self.createdAt = Date()
    }
}

/// Thread-safe session store.
actor MCPSessionStore {
    private var sessions: [String: MCPSession] = [:]

    func create(clientInfo: MCPImplementation) -> MCPSession {
        let session = MCPSession(clientInfo: clientInfo)
        sessions[session.id] = session
        return session
    }

    func get(_ id: String) -> MCPSession? {
        sessions[id]
    }

    func remove(_ id: String) {
        sessions.removeValue(forKey: id)
    }

    var activeSessions: [MCPSession] {
        Array(sessions.values)
    }

    var count: Int {
        sessions.count
    }
}
