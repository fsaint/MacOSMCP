import Foundation
import SwiftUI

/// In-memory activity log for the server dashboard.
@Observable
final class ActivityLogger: @unchecked Sendable {
    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
    }

    private(set) var entries: [Entry] = []
    private let lock = NSLock()
    private let maxEntries = 200

    func log(_ message: String) {
        let entry = Entry(timestamp: Date(), message: message)
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}
