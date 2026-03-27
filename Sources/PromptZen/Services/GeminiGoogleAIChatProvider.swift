import Foundation

/// [Google AI Studio / Gemini API](https://ai.google.dev/gemini-api/docs/quickstart) `generateContent` with `x-goog-api-key`.
struct GeminiGoogleAIChatProvider: LLMChatProvider {
    enum Failure: Error, LocalizedError {
        case missingAPIKey
        case emptyModel
        case invalidModelID
        case httpError(statusCode: Int, body: String)
        case emptyAssistantMessage
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Gemini API key is missing (Google AI Studio)."
            case .emptyModel:
                return "Gemini model id is empty."
            case .invalidModelID:
                return "Model id must not contain slashes; use e.g. gemini-2.5-flash."
            case .httpError(let code, let body):
                return "HTTP \(code): \(body)"
            case .emptyAssistantMessage:
                return "Gemini returned no text."
            case .decoding(let msg):
                return "Could not read Gemini response: \(msg)"
            }
        }
    }

    let apiKey: String
    /// Model id only, e.g. `gemini-2.5-flash` (not `models/...`).
    let model: String
    let sortPriority: Int

    var id: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "gemini" : "gemini:\(m)"
    }

    var displayName: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "Gemini" : m
    }

    func complete(userText: String, timeout: TimeInterval) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw Failure.missingAPIKey }

        var modelId = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelId.isEmpty else { throw Failure.emptyModel }
        if modelId.hasPrefix("models/") {
            modelId = String(modelId.dropFirst("models/".count))
        }
        guard !modelId.contains("/") else { throw Failure.invalidModelID }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent") else {
            throw Failure.invalidModelID
        }

        let body = GeminiGenerateRequest(
            contents: [
                .init(parts: [.init(text: userText)])
            ]
        )
        let payload = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
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

        let decoded: GeminiGenerateResponse
        do {
            decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        } catch {
            throw Failure.decoding(error.localizedDescription)
        }

        let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            throw Failure.emptyAssistantMessage
        }
        return text
    }
}

private struct GeminiGenerateRequest: Encodable {
    let contents: [GeminiContent]
    struct GeminiContent: Encodable {
        let parts: [GeminiPart]
    }
    struct GeminiPart: Encodable {
        let text: String
    }
}

private struct GeminiGenerateResponse: Decodable {
    let candidates: [GeminiCandidate]?
    struct GeminiCandidate: Decodable {
        let content: GeminiContentOut?
    }
    struct GeminiContentOut: Decodable {
        let parts: [GeminiPartOut]?
    }
    struct GeminiPartOut: Decodable {
        let text: String?
    }
}
