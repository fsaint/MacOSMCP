import Foundation

/// List or search songs in the user's Apple Music library.
struct AppleMusicLibrarySongsTool: MCPToolHandler {
    let service: MusicKitService

    var definition: MCPTool {
        MCPTool(
            name: "apple_music_library_songs",
            description: "List or search songs in the user's Apple Music library",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "search": [
                        "type": "string",
                        "description": "Optional search term to filter library songs"
                    ],
                    "limit": [
                        "type": "integer",
                        "description": "Maximum number of results (default 25, max 25)",
                        "default": 25
                    ]
                ]
            ])
        )
    }

    func call(arguments: [String: Any]) async -> MCPToolCallResult {
        let search = arguments["search"] as? String
        let limit = (arguments["limit"] as? Int) ?? 25

        do {
            let results = try await service.librarySongs(searchTerm: search, limit: limit)
            let json = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            return .text(String(data: json, encoding: .utf8) ?? "[]")
        } catch {
            return .error("Failed to fetch library songs: \(error.localizedDescription)")
        }
    }
}

/// List or search albums in the user's Apple Music library.
struct AppleMusicLibraryAlbumsTool: MCPToolHandler {
    let service: MusicKitService

    var definition: MCPTool {
        MCPTool(
            name: "apple_music_library_albums",
            description: "List or search albums in the user's Apple Music library",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "search": [
                        "type": "string",
                        "description": "Optional search term to filter library albums"
                    ],
                    "limit": [
                        "type": "integer",
                        "description": "Maximum number of results (default 25, max 25)",
                        "default": 25
                    ]
                ]
            ])
        )
    }

    func call(arguments: [String: Any]) async -> MCPToolCallResult {
        let search = arguments["search"] as? String
        let limit = (arguments["limit"] as? Int) ?? 25

        do {
            let results = try await service.libraryAlbums(searchTerm: search, limit: limit)
            let json = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            return .text(String(data: json, encoding: .utf8) ?? "[]")
        } catch {
            return .error("Failed to fetch library albums: \(error.localizedDescription)")
        }
    }
}

/// List playlists in the user's Apple Music library.
struct AppleMusicLibraryPlaylistsTool: MCPToolHandler {
    let service: MusicKitService

    var definition: MCPTool {
        MCPTool(
            name: "apple_music_library_playlists",
            description: "List playlists in the user's Apple Music library",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "limit": [
                        "type": "integer",
                        "description": "Maximum number of results (default 25, max 25)",
                        "default": 25
                    ]
                ]
            ])
        )
    }

    func call(arguments: [String: Any]) async -> MCPToolCallResult {
        let limit = (arguments["limit"] as? Int) ?? 25

        do {
            let results = try await service.libraryPlaylists(limit: limit)
            let json = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            return .text(String(data: json, encoding: .utf8) ?? "[]")
        } catch {
            return .error("Failed to fetch library playlists: \(error.localizedDescription)")
        }
    }
}
