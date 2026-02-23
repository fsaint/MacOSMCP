import Foundation

/// Search the Apple Music catalog for songs, albums, artists, and playlists.
struct AppleMusicSearchTool: MCPToolHandler {
    let service: MusicKitService

    var definition: MCPTool {
        MCPTool(
            name: "apple_music_search",
            description: "Search the Apple Music catalog for songs, albums, artists, and playlists",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Search query (artist name, song title, album name, etc.)"
                    ],
                    "limit": [
                        "type": "integer",
                        "description": "Maximum number of results per type (default 10, max 25)",
                        "default": 10
                    ]
                ],
                "required": ["query"]
            ])
        )
    }

    func call(arguments: [String: Any]) async -> MCPToolCallResult {
        guard let query = arguments["query"] as? String, !query.isEmpty else {
            return .error("Missing required parameter: query")
        }

        let limit = (arguments["limit"] as? Int) ?? 10

        do {
            let results = try await service.searchCatalog(query: query, limit: limit)
            let json = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            return .text(String(data: json, encoding: .utf8) ?? "[]")
        } catch {
            return .error("Search failed: \(error.localizedDescription)")
        }
    }
}
