import Foundation

/// Non-streaming Ollama [`POST /api/chat`](https://github.com/ollama/ollama/blob/main/docs/api.md).
struct OllamaChatProvider: LLMChatProvider {
    enum Failure: Error, LocalizedError {
        case invalidBaseURL
        case httpError(statusCode: Int, body: String)
        case ollamaAPIError(String)
        case emptyAssistantMessage
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "Invalid Ollama base URL."
            case .httpError(let code, let body):
                return "HTTP \(code): \(body)"
            case .ollamaAPIError(let msg):
                return msg
            case .emptyAssistantMessage:
                return "Ollama returned an empty assistant message."
            case .decoding(let msg):
                return "Could not read response: \(msg)"
            }
        }
    }

    let baseURLString: String
    let model: String
    /// Ollama Cloud: send `Authorization: Bearer …` per https://docs.ollama.com/api/authentication — empty for local server.
    let apiKey: String
    let sortPriority: Int

    var id: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "ollama" : "ollama:\(m)"
    }

    var displayName: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "Ollama" : m
    }

    init(baseURLString: String, model: String, apiKey: String, sortPriority: Int = 0) {
        self.baseURLString = baseURLString
        self.model = model
        self.apiKey = apiKey
        self.sortPriority = sortPriority
    }

    func complete(userText: String, timeout: TimeInterval) async throws -> String {
        let url = try Self.chatEndpointURL(from: baseURLString)

        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else {
            throw Failure.ollamaAPIError("Model name is empty.")
        }

        let body = OllamaChatRequest(
            model: modelName,
            messages: [OllamaChatMessage(role: "user", content: userText)],
            stream: false
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout + 5
        let session = URLSession(configuration: config)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw Failure.httpError(statusCode: -1, body: "No HTTP response")
        }

        let bodyPreview = String(data: data, encoding: .utf8) ?? ""

        if http.statusCode >= 400 {
            if let err = try? JSONDecoder().decode(OllamaErrorEnvelope.self, from: data), !err.error.isEmpty {
                throw Failure.httpError(statusCode: http.statusCode, body: err.error)
            }
            throw Failure.httpError(statusCode: http.statusCode, body: String(bodyPreview.prefix(500)))
        }

        let decoder = JSONDecoder()
        let chatResponse: OllamaChatResponse
        do {
            chatResponse = try decoder.decode(OllamaChatResponse.self, from: data)
        } catch {
            throw Failure.decoding(error.localizedDescription)
        }

        if let apiErr = chatResponse.error, !apiErr.isEmpty {
            throw Failure.ollamaAPIError(apiErr)
        }

        let content = chatResponse.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if content.isEmpty {
            throw Failure.emptyAssistantMessage
        }
        return content
    }

    /// Resolves `https://ollama.com`, `https://ollama.com/`, or `…/api/chat` to a single chat POST URL.
    private static func chatEndpointURL(from raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            throw Failure.invalidBaseURL
        }
        guard components.scheme == "http" || components.scheme == "https" else {
            throw Failure.invalidBaseURL
        }
        guard components.host?.isEmpty == false else {
            throw Failure.invalidBaseURL
        }
        let path = components.path
        if path.isEmpty || path == "/" {
            components.path = "/api/chat"
        } else if path.hasSuffix("/api/chat") {
            // already correct
        } else {
            components.path = path.hasSuffix("/") ? path + "api/chat" : path + "/api/chat"
        }
        guard let url = components.url else {
            throw Failure.invalidBaseURL
        }
        return url
    }
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
}

private struct OllamaChatMessage: Encodable {
    let role: String
    let content: String
}

private struct OllamaChatResponse: Decodable {
    let model: String?
    let message: OllamaAssistantMessage?
    let done: Bool?
    let error: String?
}

private struct OllamaAssistantMessage: Decodable {
    let role: String?
    let content: String?
}

private struct OllamaErrorEnvelope: Decodable {
    let error: String
}
