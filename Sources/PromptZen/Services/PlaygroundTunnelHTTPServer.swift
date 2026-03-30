import FlyingFox
import FlyingSocks
import Foundation

private struct TunnelChatIncoming: Decodable {
    let message: String?
    let secret: String?
}

private struct TunnelChatOutgoing: Encodable {
    let reply: String?
    let error: String?
}

/// Local HTTP server: `GET /` (chat HTML) and `POST /chat` (proxies to Playground LLM routing).
actor PlaygroundTunnelHTTPServer {
    private var server: HTTPServer?
    private var runTask: Task<Void, Never>?

    func start(port: UInt16, tunnelSecret: String) async throws {
        await stop()
        // 0.0.0.0: reachable on this Mac via 127.0.0.1 and from other devices on the LAN via the Mac’s IPv4.
        let address: sockaddr_in = try .inet(ip4: "0.0.0.0", port: port)
        let srv = HTTPServer(address: address)
        let htmlData = PlaygroundTunnelWebHTML.page(injectedSecret: tunnelSecret).data(using: .utf8) ?? Data()

        let cors: HTTPHeaders = [
            HTTPHeader("Access-Control-Allow-Origin"): "*",
            HTTPHeader("Access-Control-Allow-Headers"): "Content-Type, Authorization",
            HTTPHeader("Access-Control-Allow-Methods"): "POST, OPTIONS, GET",
        ]

        await srv.appendRoute(HTTPRoute(methods: [HTTPMethod.GET], path: "/")) { _ in
            HTTPResponse(
                statusCode: .ok,
                headers: [
                    HTTPHeader.contentType: "text/html; charset=utf-8",
                    HTTPHeader("Cache-Control"): "no-store",
                ],
                body: htmlData
            )
        }

        await srv.appendRoute(HTTPRoute(methods: [HTTPMethod.OPTIONS], path: "/chat")) { _ in
            HTTPResponse(statusCode: .noContent, headers: cors, body: Data())
        }

        await srv.appendRoute(HTTPRoute(methods: [HTTPMethod.POST], path: "/chat")) { request in
            await Self.handleChatPOST(request: request, cors: cors)
        }

        runTask = Task {
            try? await srv.run()
        }

        try await srv.waitUntilListening(timeout: 12)
        server = srv
    }

    func stop() async {
        if let s = server {
            await s.stop(timeout: 1)
        }
        server = nil
        runTask?.cancel()
        runTask = nil
    }

    private static func handleChatPOST(request: HTTPRequest, cors: HTTPHeaders) async -> HTTPResponse {
        var headers = cors
        headers[HTTPHeader.contentType] = "application/json; charset=utf-8"

        func jsonResponse(status: HTTPStatusCode, reply: String?, error: String?) -> HTTPResponse {
            let out = TunnelChatOutgoing(reply: reply, error: error)
            let data = (try? JSONEncoder().encode(out)) ?? Data("{}".utf8)
            return HTTPResponse(statusCode: status, headers: headers, body: data)
        }

        do {
            let body = try await request.bodyData
            let incoming = try JSONDecoder().decode(TunnelChatIncoming.self, from: body)
            let auth = request.headers[.authorization]
            let text = try await PlaygroundTunnelChatService.completeChat(
                userMessage: incoming.message ?? "",
                authorizationHeader: auth,
                bodySecret: incoming.secret
            )
            return jsonResponse(status: .ok, reply: text, error: nil)
        } catch let e as PlaygroundTunnelError {
            let code: HTTPStatusCode = {
                switch e {
                case .unauthorized: return HTTPStatusCode(401, phrase: "Unauthorized")
                case .emptyMessage, .invalidJSON: return .badRequest
                }
            }()
            return jsonResponse(status: code, reply: nil, error: e.localizedDescription)
        } catch let e as ChatProviderRouterError {
            return jsonResponse(status: .badGateway, reply: nil, error: e.localizedDescription)
        } catch is DecodingError {
            return jsonResponse(
                status: .badRequest,
                reply: nil,
                error: "Invalid or empty JSON body. If you are on iPhone Safari, disconnect and reconnect so the page picks up the latest tunnel UI."
            )
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            let detail = msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Request failed." : msg
            return jsonResponse(status: .internalServerError, reply: nil, error: detail)
        }
    }
}
