# MacOS MCP - Apple Music

A macOS menu bar app that exposes Apple Music as an [MCP](https://modelcontextprotocol.io/) server, letting Claude and other AI assistants search, browse, and manage your Apple Music library and playlists.

## How It Works

The app runs a local HTTP server on `127.0.0.1:9200` that speaks the MCP protocol (JSON-RPC 2.0). It uses MusicKit to interact with Apple Music and authenticates requests with a bearer token stored at `~/.config/apple-music-mcp/token`.

The menu bar UI shows server status, MusicKit authorization, the bearer token, and a copyable Claude Code config snippet for easy integration.

## MCP Tools

| Tool | Description |
|------|-------------|
| `apple_music_search` | Search the Apple Music catalog for songs, albums, artists, and playlists |
| `apple_music_library_songs` | List or search songs in your library |
| `apple_music_library_albums` | List or search albums in your library |
| `apple_music_library_playlists` | List playlists in your library |
| `apple_music_add_to_playlist` | Add songs to an existing playlist |
| `apple_music_create_playlist` | Create a new playlist |
| `apple_music_get_recommendations` | Get personalized recommendations |

## Requirements

- macOS 14.0+
- Apple Music subscription (for MusicKit authorization)

## Setup

1. Build and run the Xcode project in `MCPManager/`
2. Grant Apple Music access when prompted
3. Copy the Claude Code config from the menu bar dropdown into your Claude Code MCP settings

## Claude Code Configuration

Add this to your MCP settings (the token is auto-generated and shown in the menu bar):

```json
{
  "mcpServers": {
    "apple-music": {
      "type": "http",
      "url": "http://127.0.0.1:9200/mcp",
      "headers": {
        "Authorization": "Bearer <your-token>"
      }
    }
  }
}
```

## Project Structure

```
MCPManager/
  Server/        - HTTP server and MCP request routing
  Services/      - MusicKit integration and activity logging
  Tools/         - MCP tool implementations
  Models/        - JSON-RPC and MCP type definitions
  Utilities/     - JSON encoding helpers
  Views/         - Menu bar UI
```

## License

MIT
