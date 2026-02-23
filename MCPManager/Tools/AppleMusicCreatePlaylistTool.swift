import Foundation

/// Create a new playlist in the user's Apple Music library.
struct AppleMusicCreatePlaylistTool: MCPToolHandler {
    let service: MusicKitService

    var definition: MCPTool {
        MCPTool(
            name: "apple_music_create_playlist",
            description: "Create a new playlist in the user's Apple Music library",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "name": [
                        "type": "string",
                        "description": "Name for the new playlist"
                    ],
                    "description": [
                        "type": "string",
                        "description": "Optional description for the playlist"
                    ]
                ],
                "required": ["name"]
            ])
        )
    }

    func call(arguments: [String: Any]) async -> MCPToolCallResult {
        guard let name = arguments["name"] as? String, !name.isEmpty else {
            return .error("Missing required parameter: name")
        }

        let description = arguments["description"] as? String

        do {
            let result = try await service.createPlaylist(name: name, description: description)
            let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .text(String(data: json, encoding: .utf8) ?? "{}")
        } catch {
            return .error("Failed to create playlist: \(error.localizedDescription)")
        }
    }
}

/// Get personalized Apple Music recommendations.
struct AppleMusicRecommendationsTool: MCPToolHandler {
    let service: MusicKitService

    var definition: MCPTool {
        MCPTool(
            name: "apple_music_get_recommendations",
            description: "Get personalized Apple Music recommendations based on listening history",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "limit": [
                        "type": "integer",
                        "description": "Maximum number of recommendation groups (default 10, max 10)",
                        "default": 10
                    ]
                ]
            ])
        )
    }

    func call(arguments: [String: Any]) async -> MCPToolCallResult {
        let limit = (arguments["limit"] as? Int) ?? 10

        do {
            let results = try await service.getRecommendations(limit: limit)
            let json = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            return .text(String(data: json, encoding: .utf8) ?? "[]")
        } catch {
            return .error("Failed to get recommendations: \(error.localizedDescription)")
        }
    }
}
