import Foundation

/// Add songs to an existing playlist in the user's library.
struct AppleMusicAddToPlaylistTool: MCPToolHandler {
    let service: MusicKitService

    var definition: MCPTool {
        MCPTool(
            name: "apple_music_add_to_playlist",
            description: "Add songs to an existing playlist in the user's Apple Music library",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "playlist_id": [
                        "type": "string",
                        "description": "The ID of the playlist to add songs to"
                    ],
                    "song_ids": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Array of song IDs to add to the playlist"
                    ]
                ],
                "required": ["playlist_id", "song_ids"]
            ])
        )
    }

    func call(arguments: [String: Any]) async -> MCPToolCallResult {
        guard let playlistId = arguments["playlist_id"] as? String else {
            return .error("Missing required parameter: playlist_id")
        }

        guard let songIds = arguments["song_ids"] as? [String], !songIds.isEmpty else {
            return .error("Missing or empty required parameter: song_ids")
        }

        do {
            let message = try await service.addToPlaylist(playlistId: playlistId, songIds: songIds)
            return .text(message)
        } catch {
            return .error("Failed to add songs to playlist: \(error.localizedDescription)")
        }
    }
}
