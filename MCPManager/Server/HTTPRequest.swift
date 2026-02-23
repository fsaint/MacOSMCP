import Foundation

/// A parsed HTTP/1.1 request from raw TCP data.
struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    var contentType: String? { headers["content-type"] }
    var sessionId: String? { headers["mcp-session-id"] }

    /// Extract bearer token from Authorization header.
    var bearerToken: String? {
        guard let auth = headers["authorization"],
              auth.lowercased().hasPrefix("bearer ") else { return nil }
        return String(auth.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }

    /// Parse an HTTP/1.1 request from raw bytes.
    /// Returns nil if the data is incomplete or malformed.
    static func parse(from data: Data) -> HTTPRequest? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }

        // Split headers and body by \r\n\r\n
        guard let headerEndRange = str.range(of: "\r\n\r\n") else { return nil }
        let headerSection = str[str.startIndex..<headerEndRange.lowerBound]
        let bodyStart = headerEndRange.upperBound

        let lines = headerSection.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }

        // Parse request line: METHOD PATH HTTP/1.1
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIdx].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        // Check if we have the full body
        let contentLength = headers["content-length"].flatMap(Int.init) ?? 0
        let bodyString = str[bodyStart...]
        let bodyData = Data(bodyString.utf8)

        guard bodyData.count >= contentLength else { return nil }

        let body = bodyData.prefix(contentLength)
        return HTTPRequest(method: method, path: path, headers: headers, body: Data(body))
    }

    /// Total byte length of the full request (headers + body) for buffer management.
    static func totalLength(from data: Data) -> Int? {
        guard let str = String(data: data, encoding: .utf8),
              let headerEndRange = str.range(of: "\r\n\r\n") else { return nil }

        let headerSection = str[str.startIndex..<headerEndRange.lowerBound]
        let lines = headerSection.split(separator: "\r\n", omittingEmptySubsequences: false)

        var contentLength = 0
        for line in lines.dropFirst() {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "0"
                contentLength = Int(value) ?? 0
                break
            }
        }

        let headerBytes = Data(str[str.startIndex...headerEndRange.upperBound].utf8).count
        let totalNeeded = headerBytes + contentLength
        return data.count >= totalNeeded ? totalNeeded : nil
    }
}
