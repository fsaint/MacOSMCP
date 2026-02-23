import SwiftUI
import MusicKit
import os
import Security

@main
struct MCPManagerApp: App {
    @State private var viewModel = ServerViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarDashboardView(viewModel: viewModel)
                .frame(width: 380, height: 500)
        } label: {
            Label("Apple Music MCP", systemImage: viewModel.isRunning ? "music.note" : "music.note.slash")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Dashboard View

struct MenuBarDashboardView: View {
    @Bindable var viewModel: ServerViewModel
    @State private var tokenRevealed = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            serverInfo
                .padding(.horizontal, 12)
                .padding(.top, 10)

            Divider()
                .padding(.top, 10)

            activityLog

            Divider()

            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(viewModel.isRunning ? "Running" : "Stopped")
                .font(.headline)
                .foregroundStyle(viewModel.isRunning ? .primary : .secondary)

            Text("127.0.0.1:9200")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    if viewModel.isRunning {
                        await viewModel.stopServer()
                    } else {
                        await viewModel.startServer()
                    }
                }
            } label: {
                Image(systemName: viewModel.isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.isRunning ? .red : .green)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Server Info

    private var serverInfo: some View {
        VStack(spacing: 8) {
            HStack {
                Label("MusicKit", systemImage: "music.quarternote.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.musicKitAuthorized {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Authorize") {
                        Task { await viewModel.requestMusicKitAuth() }
                    }
                    .controlSize(.mini)
                }
            }

            HStack {
                Label("Tools", systemImage: "wrench")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.toolCount) registered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Auth", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Bearer token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Token row
            GroupBox {
                HStack(spacing: 6) {
                    if tokenRevealed {
                        Text(viewModel.bearerToken)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                    } else {
                        Text(String(repeating: "\u{2022}", count: 24))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button {
                        tokenRevealed.toggle()
                    } label: {
                        Image(systemName: tokenRevealed ? "eye.slash" : "eye")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Bearer Token")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Config snippet with copy button
            GroupBox {
                HStack(alignment: .top) {
                    Text(viewModel.claudeConfigJSON)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(5)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.claudeConfigJSON, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(copied ? .green : .secondary)
                }
            } label: {
                Text("Claude Code Config")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Activity Log

    private var activityLog: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    viewModel.activityLogger.clear()
                }
                .controlSize(.mini)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollViewReader { proxy in
                List(viewModel.activityLogger.entries) { entry in
                    HStack(alignment: .top, spacing: 6) {
                        Text(entry.timestamp, format: .dateTime.hour().minute().second())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(entry.message)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12))
                    .listRowSeparator(.hidden)
                    .id(entry.id)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onChange(of: viewModel.activityLogger.entries.count) {
                    if let last = viewModel.activityLogger.entries.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Regenerate Token") {
                viewModel.regenerateToken()
            }
            .controlSize(.small)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Server ViewModel

@Observable
@MainActor
final class ServerViewModel {
    private(set) var isRunning = false
    private(set) var musicKitAuthorized = false
    private(set) var toolCount = 7
    private(set) var bearerToken: String

    let activityLogger = ActivityLogger()

    private let httpServer = HTTPServer(port: 9200)
    private let musicKitService = MusicKitService()
    private var router: MCPRequestRouter?
    private let logger = Logger(subsystem: "com.mcpmanager.app", category: "App")

    var claudeConfigJSON: String {
        """
        {"mcpServers":{"apple-music":{"type":"http","url":"http://localhost:9200/mcp","headers":{"Authorization":"Bearer \(bearerToken)"}}}}
        """
    }

    init() {
        bearerToken = Self.loadOrCreateToken()
        musicKitAuthorized = MusicAuthorization.currentStatus == .authorized

        Task {
            await requestMusicKitAuth()
            await startServer()
        }
    }

    func regenerateToken() {
        bearerToken = Self.generateToken()
        Self.saveToken(bearerToken)
        activityLogger.log("Bearer token regenerated — update your Claude Code config")
    }

    func requestMusicKitAuth() async {
        let status = await MusicAuthorization.request()
        musicKitAuthorized = status == .authorized
        activityLogger.log("MusicKit authorization: \(status == .authorized ? "granted" : "denied")")
    }

    func startServer() async {
        guard !isRunning else { return }

        let toolRegistry = ToolRegistry()
        await toolRegistry.registerAppleMusicTools(service: musicKitService)
        let router = MCPRequestRouter(toolRegistry: toolRegistry, activityLogger: activityLogger, bearerToken: bearerToken)
        self.router = router

        do {
            try await httpServer.start { request in
                await router.handle(request)
            }
            isRunning = true
            activityLogger.log("Server started on 127.0.0.1:9200")

            await httpServer.setCallbacks(
                onConnect: { [activityLogger] clientId in
                    activityLogger.log("Connection: \(clientId)")
                },
                onDisconnect: { _ in }
            )
        } catch {
            activityLogger.log("Failed to start server: \(error.localizedDescription)")
            logger.error("Failed to start: \(error.localizedDescription)")
        }
    }

    func stopServer() async {
        await httpServer.stop()
        isRunning = false
        activityLogger.log("Server stopped")
    }

    // MARK: - Token Persistence (File)

    private static var tokenFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("apple-music-mcp")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("token")
    }

    private static func loadOrCreateToken() -> String {
        if let existing = loadToken() {
            return existing
        }
        let token = generateToken()
        saveToken(token)
        return token
    }

    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func loadToken() -> String? {
        try? String(contentsOf: tokenFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func saveToken(_ token: String) {
        try? token.write(to: tokenFileURL, atomically: true, encoding: .utf8)
        // Restrict to owner only: chmod 600
        chmod(tokenFileURL.path, 0o600)
    }
}

// MARK: - HTTPServer callback extension

extension HTTPServer {
    func setCallbacks(
        onConnect: @escaping @Sendable (String) -> Void,
        onDisconnect: @escaping @Sendable (String) -> Void
    ) {
        self.onClientConnected = onConnect
        self.onClientDisconnected = onDisconnect
    }
}
