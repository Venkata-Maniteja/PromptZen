import Foundation

/// [Cohere Chat API v2](https://docs.cohere.com/v2/docs/chat-api) (`POST https://api.cohere.ai/v2/chat`).
struct CohereV2ChatProvider: LLMChatProvider {
    enum Failure: Error, LocalizedError {
        case missingAPIKey
        case emptyModel
        case httpError(statusCode: Int, body: String)
        case emptyAssistantMessage
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Cohere API key is missing."
            case .emptyModel:
                return "Cohere model id is empty."
            case .httpError(let code, let body):
                return "HTTP \(code): \(body)"
            case .emptyAssistantMessage:
                return "Cohere returned no assistant text."
            case .decoding(let msg):
                return "Could not read Cohere response: \(msg)"
            }
        }
    }

    let apiKey: String
    let model: String
    let sortPriority: Int

    var id: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "cohere" : "cohere:\(m)"
    }

    var displayName: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "Cohere" : m
    }

    func complete(userText: String, timeout: TimeInterval) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw Failure.missingAPIKey }
        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else { throw Failure.emptyModel }

        let url = URL(string: "https://api.cohere.ai/v2/chat")!
        let body = CohereRequest(
            model: modelName,
            messages: [.init(role: "user", content: userText)]
        )
        let payload = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = payload

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout + 5
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Failure.httpError(statusCode: -1, body: "No HTTP response")
        }
        if http.statusCode >= 400 {
            let preview = String(data: data, encoding: .utf8) ?? ""
            throw Failure.httpError(statusCode: http.statusCode, body: String(preview.prefix(500)))
        }

        let decoded: CohereResponse
        do {
            decoded = try JSONDecoder().decode(CohereResponse.self, from: data)
        } catch {
            throw Failure.decoding(error.localizedDescription)
        }

        let parts = decoded.message?.content ?? []
        let text = parts.compactMap { block -> String? in
            guard block.type?.lowercased() == "text" else { return nil }
            return block.text
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            throw Failure.emptyAssistantMessage
        }
        return text
    }
}

private struct CohereRequest: Encodable {
    let model: String
    let messages: [CohereMsg]
    struct CohereMsg: Encodable {
        let role: String
        let content: String
    }
}

private struct CohereResponse: Decodable {
    let message: CohereAssistant?
    struct CohereAssistant: Decodable {
        let content: [CohereBlock]?
    }
    struct CohereBlock: Decodable {
        let type: String?
        let text: String?
    }
}
