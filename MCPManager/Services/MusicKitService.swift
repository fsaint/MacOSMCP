import Foundation
import MusicKit
import os

/// Central service for all Apple Music / MusicKit API calls.
actor MusicKitService {
    private let logger = Logger(subsystem: "com.mcpmanager.app", category: "MusicKit")

    // MARK: - Authorization

    var authorizationStatus: MusicAuthorization.Status {
        MusicAuthorization.currentStatus
    }

    func requestAuthorization() async -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        logger.info("MusicKit authorization: \(String(describing: status))")
        return status
    }

    // MARK: - Catalog Search

    func searchCatalog(query: String, types: [String] = [], limit: Int = 10) async throws -> [[String: Any]] {
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self, Album.self, Artist.self, Playlist.self])
        request.limit = min(limit, 25)

        let response = try await request.response()
        var results: [[String: Any]] = []

        for song in response.songs {
            results.append([
                "type": "song",
                "id": song.id.rawValue,
                "title": song.title,
                "artistName": song.artistName,
                "albumTitle": song.albumTitle ?? "",
                "duration": song.duration.map { Int($0) } as Any
            ])
        }

        for album in response.albums {
            results.append([
                "type": "album",
                "id": album.id.rawValue,
                "title": album.title,
                "artistName": album.artistName,
                "trackCount": album.trackCount as Any
            ])
        }

        for artist in response.artists {
            results.append([
                "type": "artist",
                "id": artist.id.rawValue,
                "name": artist.name
            ])
        }

        for playlist in response.playlists {
            results.append([
                "type": "playlist",
                "id": playlist.id.rawValue,
                "name": playlist.name,
                "curatorName": playlist.curatorName ?? ""
            ])
        }

        return results
    }

    // MARK: - Library Songs

    func librarySongs(searchTerm: String? = nil, limit: Int = 25) async throws -> [[String: Any]] {
        var results: [[String: Any]] = []

        if let searchTerm, !searchTerm.isEmpty {
            var request = MusicLibrarySearchRequest(term: searchTerm, types: [Song.self])
            request.limit = min(limit, 25)
            let response = try await request.response()
            for song in response.songs {
                results.append(songDict(song))
            }
        } else {
            var request = MusicLibraryRequest<Song>()
            request.limit = min(limit, 25)
            let response = try await request.response()
            for song in response.items {
                results.append(songDict(song))
            }
        }

        return results
    }

    // MARK: - Library Albums

    func libraryAlbums(searchTerm: String? = nil, limit: Int = 25) async throws -> [[String: Any]] {
        var results: [[String: Any]] = []

        if let searchTerm, !searchTerm.isEmpty {
            var request = MusicLibrarySearchRequest(term: searchTerm, types: [Album.self])
            request.limit = min(limit, 25)
            let response = try await request.response()
            for album in response.albums {
                results.append(albumDict(album))
            }
        } else {
            var request = MusicLibraryRequest<Album>()
            request.limit = min(limit, 25)
            let response = try await request.response()
            for album in response.items {
                results.append(albumDict(album))
            }
        }

        return results
    }

    // MARK: - Library Playlists

    func libraryPlaylists(limit: Int = 25) async throws -> [[String: Any]] {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = min(limit, 25)
        let response = try await request.response()

        return response.items.map { playlist in
            [
                "id": playlist.id.rawValue,
                "name": playlist.name,
                "description": playlist.standardDescription ?? ""
            ]
        }
    }

    // MARK: - Add to Playlist

    func addToPlaylist(playlistId: String, songIds: [String]) async throws -> String {
        // Verify playlist exists
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(playlistId))
        let response = try await request.response()

        guard let playlist = response.items.first else {
            throw MusicKitServiceError.playlistNotFound(playlistId)
        }

        // Use MusicDataRequest to add tracks (MusicLibrary.shared.add is unavailable on macOS)
        let url = URL(string: "https://api.music.apple.com/v1/me/library/playlists/\(playlistId)/tracks")!
        var dataRequest = MusicDataRequest(urlRequest: URLRequest(url: url))
        let tracks: [[String: Any]] = songIds.map { ["id": $0, "type": "songs"] }
        let body = try JSONSerialization.data(withJSONObject: ["data": tracks])
        dataRequest = MusicDataRequest(urlRequest: {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return req
        }())
        _ = try await dataRequest.response()

        return "Added \(songIds.count) song(s) to playlist '\(playlist.name)'"
    }

    // MARK: - Create Playlist

    func createPlaylist(name: String, description: String? = nil) async throws -> [String: Any] {
        // Use MusicDataRequest POST to create playlist (MusicLibrary.shared.createPlaylist is unavailable on macOS)
        let url = URL(string: "https://api.music.apple.com/v1/me/library/playlists")!
        var attributes: [String: Any] = ["name": name]
        if let description { attributes["description"] = description }
        let payload: [String: Any] = ["attributes": attributes]
        let body = try JSONSerialization.data(withJSONObject: payload)

        let dataRequest = MusicDataRequest(urlRequest: {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return req
        }())

        let response = try await dataRequest.response()

        // Parse created playlist ID from response
        if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
           let dataArray = json["data"] as? [[String: Any]],
           let first = dataArray.first,
           let id = first["id"] as? String {
            return ["id": id, "name": name, "description": description ?? ""]
        }

        return ["name": name, "description": description ?? "", "status": "created"]
    }

    // MARK: - Recommendations

    func getRecommendations(limit: Int = 10) async throws -> [[String: Any]] {
        // Use a personal recommendation request
        var request = MusicPersonalRecommendationsRequest()
        request.limit = min(limit, 10)
        let response = try await request.response()

        var results: [[String: Any]] = []
        for recommendation in response.recommendations {
            var recDict: [String: Any] = [
                "title": recommendation.title ?? "Recommendation"
            ]

            var items: [[String: Any]] = []
            for album in recommendation.albums {
                items.append([
                    "type": "album",
                    "id": album.id.rawValue,
                    "title": album.title,
                    "artistName": album.artistName
                ])
            }
            for playlist in recommendation.playlists {
                items.append([
                    "type": "playlist",
                    "id": playlist.id.rawValue,
                    "name": playlist.name
                ])
            }
            recDict["items"] = items
            results.append(recDict)
        }

        return results
    }

    // MARK: - Helpers

    private func songDict(_ song: Song) -> [String: Any] {
        [
            "id": song.id.rawValue,
            "title": song.title,
            "artistName": song.artistName,
            "albumTitle": song.albumTitle ?? "",
            "duration": song.duration.map { Int($0) } as Any
        ]
    }

    private func albumDict(_ album: Album) -> [String: Any] {
        [
            "id": album.id.rawValue,
            "title": album.title,
            "artistName": album.artistName,
            "trackCount": album.trackCount as Any
        ]
    }
}

enum MusicKitServiceError: LocalizedError {
    case playlistNotFound(String)
    case songNotFound(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .playlistNotFound(let id): return "Playlist not found: \(id)"
        case .songNotFound(let id): return "Song not found: \(id)"
        case .unauthorized: return "MusicKit not authorized"
        }
    }
}
