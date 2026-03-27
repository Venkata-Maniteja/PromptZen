import Foundation

/// OpenAI-style `POST …/chat/completions` (used by Groq, Mistral, GitHub Models, Hugging Face router, Vercel AI Gateway, Cerebras, OpenRouter, OpenCode Zen chat models, NVIDIA NIM, etc.).
struct OpenAICompatibleChatProvider: LLMChatProvider {
    enum Failure: Error, LocalizedError {
        case missingAPIKey
        case invalidBaseURL
        case httpError(statusCode: Int, body: String)
        case apiError(String)
        case emptyAssistantMessage
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "API key is missing."
            case .invalidBaseURL:
                return "Invalid API base URL."
            case .httpError(let code, let body):
                return "HTTP \(code): \(body)"
            case .apiError(let msg):
                return msg
            case .emptyAssistantMessage:
                return "The model returned an empty assistant message."
            case .decoding(let msg):
                return "Could not read response: \(msg)"
            }
        }
    }

    /// Short id segment, e.g. `groq`, `openrouter`.
    let idPrefix: String
    let baseURLString: String
    let apiKey: String
    let model: String
    let extraHTTPHeaders: [String: String]
    let sortPriority: Int

    var id: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = idPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = p.isEmpty ? "openai-compat" : p
        return m.isEmpty ? prefix : "\(prefix):\(m)"
    }

    var displayName: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? idPrefix : m
    }

    init(
        idPrefix: String,
        baseURLString: String,
        apiKey: String,
        model: String,
        extraHTTPHeaders: [String: String] = [:],
        sortPriority: Int = 0
    ) {
        self.idPrefix = idPrefix
        self.baseURLString = baseURLString
        self.apiKey = apiKey
        self.model = model
        self.extraHTTPHeaders = extraHTTPHeaders
        self.sortPriority = sortPriority
    }

    func complete(userText: String, timeout: TimeInterval) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw Failure.missingAPIKey }

        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else {
            throw Failure.apiError("Model id is empty.")
        }

        let url = try Self.chatCompletionsURL(from: baseURLString)
        let body = OAIChatRequest(
            model: modelName,
            messages: [OAIChatMessage(role: "user", content: userText)],
            stream: false
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        for (k, v) in extraHTTPHeaders {
            let kk = k.trimmingCharacters(in: .whitespacesAndNewlines)
            if !kk.isEmpty { request.setValue(v, forHTTPHeaderField: kk) }
        }
        request.httpBody = payload

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
            if let env = try? JSONDecoder().decode(OAITopLevelErrorEnvelope.self, from: data),
               let msg = env.error?.message, !msg.isEmpty {
                throw Failure.httpError(statusCode: http.statusCode, body: msg)
            }
            throw Failure.httpError(statusCode: http.statusCode, body: String(bodyPreview.prefix(500)))
        }

        let decoded: OAIChatCompletionsResponse
        do {
            decoded = try JSONDecoder().decode(OAIChatCompletionsResponse.self, from: data)
        } catch {
            throw Failure.decoding(error.localizedDescription)
        }

        if let msg = decoded.error?.message, !msg.isEmpty {
            throw Failure.apiError(msg)
        }

        guard let choice = decoded.choices?.first, let message = choice.message else {
            throw Failure.emptyAssistantMessage
        }

        let content = message.resolvedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            throw Failure.emptyAssistantMessage
        }
        return content
    }

    private static func chatCompletionsURL(from raw: String) throws -> URL {
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
        if path.hasSuffix("/chat/completions") {
            // ok
        } else if path.isEmpty || path == "/" {
            components.path = "/v1/chat/completions"
        } else if path.hasSuffix("/v1") || path.hasSuffix("/v1/") {
            let base = path.hasSuffix("/") ? String(path.dropLast()) : path
            components.path = base + "/chat/completions"
        } else if path.hasSuffix("/api/v1") || path.hasSuffix("/api/v1/") {
            let base = path.hasSuffix("/") ? String(path.dropLast()) : path
            components.path = base + "/chat/completions"
        } else {
            components.path = path.hasSuffix("/") ? path + "chat/completions" : path + "/chat/completions"
        }
        guard let url = components.url else {
            throw Failure.invalidBaseURL
        }
        return url
    }
}

// MARK: - Shared OpenAI JSON types

private struct OAIChatRequest: Encodable {
    let model: String
    let messages: [OAIChatMessage]
    let stream: Bool
}

private struct OAIChatMessage: Encodable {
    let role: String
    let content: String
}

private struct OAIChatCompletionsResponse: Decodable {
    let choices: [OAIChoice]?
    let error: OAIEnvelopeError?

    struct OAIEnvelopeError: Decodable {
        let message: String?
    }

    struct OAIChoice: Decodable {
        let message: OAIAssistantMessage?
    }

    struct OAIAssistantMessage: Decodable {
        let role: String?
        let content: MessageContent?
    }

    enum MessageContent: Decodable {
        case text(String)
        case parts([ContentPart])

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) {
                self = .text(s)
                return
            }
            let parts = try c.decode([ContentPart].self)
            self = .parts(parts)
        }

        var flattenedText: String {
            switch self {
            case .text(let s):
                return s
            case .parts(let parts):
                return parts.compactMap(\.text).joined(separator: "\n")
            }
        }
    }

    struct ContentPart: Decodable {
        let type: String?
        let text: String?
    }
}

private extension OAIChatCompletionsResponse.OAIAssistantMessage {
    var resolvedText: String {
        content?.flattenedText ?? ""
    }
}

private struct OAITopLevelErrorEnvelope: Decodable {
    let error: Nested?
    struct Nested: Decodable {
        let message: String?
    }
}
