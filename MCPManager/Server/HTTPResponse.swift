import Foundation

/// HTTP response builder for raw TCP connections.
struct HTTPResponse: Sendable {
    let statusCode: Int
    let statusText: String
    let headers: [String: String]
    let body: Data

    /// Serialize to HTTP/1.1 wire format.
    func serialize() -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        var allHeaders = headers
        allHeaders["Content-Length"] = "\(body.count)"
        allHeaders["Connection"] = "close"

        for (key, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"
        var data = Data(response.utf8)
        data.append(body)
        return data
    }

    // MARK: - Factories

    static func json(_ body: Data, status: Int = 200, extraHeaders: [String: String] = [:]) -> HTTPResponse {
        var headers = ["Content-Type": "application/json"]
        for (k, v) in extraHeaders { headers[k] = v }
        return HTTPResponse(
            statusCode: status,
            statusText: statusText(for: status),
            headers: headers,
            body: body
        )
    }

    static func accepted(extraHeaders: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(
            statusCode: 202,
            statusText: "Accepted",
            headers: extraHeaders,
            body: Data()
        )
    }

    static func methodNotAllowed(allow: String = "POST") -> HTTPResponse {
        HTTPResponse(
            statusCode: 405,
            statusText: "Method Not Allowed",
            headers: ["Allow": allow],
            body: Data()
        )
    }

    static func unauthorized() -> HTTPResponse {
        let body = Data("{\"error\":\"Unauthorized\"}".utf8)
        return HTTPResponse(
            statusCode: 401,
            statusText: "Unauthorized",
            headers: [
                "Content-Type": "application/json",
                "WWW-Authenticate": "Bearer"
            ],
            body: body
        )
    }

    static func notFound() -> HTTPResponse {
        HTTPResponse(
            statusCode: 404,
            statusText: "Not Found",
            headers: [:],
            body: Data()
        )
    }

    static func badRequest(_ message: String = "Bad Request") -> HTTPResponse {
        let body = Data("{\"error\":\"\(message)\"}".utf8)
        return HTTPResponse(
            statusCode: 400,
            statusText: "Bad Request",
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }

    static func internalServerError(_ message: String = "Internal Server Error") -> HTTPResponse {
        let body = Data("{\"error\":\"\(message)\"}".utf8)
        return HTTPResponse(
            statusCode: 500,
            statusText: "Internal Server Error",
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }

    private static func statusText(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
