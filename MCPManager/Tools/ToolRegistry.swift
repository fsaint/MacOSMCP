import Foundation

/// Protocol for MCP tool handlers.
protocol MCPToolHandler: Sendable {
    var definition: MCPTool { get }
    func call(arguments: [String: Any]) async -> MCPToolCallResult
}

/// Central registry that holds all tools and dispatches calls.
actor ToolRegistry {
    private var handlers: [String: MCPToolHandler] = [:]

    func register(_ handler: MCPToolHandler) {
        handlers[handler.definition.name] = handler
    }

    func listTools() -> [MCPTool] {
        handlers.values.map(\.definition).sorted { $0.name < $1.name }
    }

    func call(name: String, arguments: [String: Any]) async -> MCPToolCallResult {
        guard let handler = handlers[name] else {
            return .error("Unknown tool: \(name)")
        }
        return await handler.call(arguments: arguments)
    }

    /// Register all Apple Music tools with the given service.
    func registerAppleMusicTools(service: MusicKitService) {
        register(AppleMusicSearchTool(service: service))
        register(AppleMusicLibrarySongsTool(service: service))
        register(AppleMusicLibraryAlbumsTool(service: service))
        register(AppleMusicLibraryPlaylistsTool(service: service))
        register(AppleMusicAddToPlaylistTool(service: service))
        register(AppleMusicCreatePlaylistTool(service: service))
        register(AppleMusicRecommendationsTool(service: service))
    }
}
