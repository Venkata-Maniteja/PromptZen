import Foundation

enum ChatFailover {
    /// Whether the router should try the next provider after this error.
    static func shouldTryNext(after error: Error) -> Bool {
        if error is CancellationError { return false }
        if let url = error as? URLError {
            switch url.code {
            case .cancelled:
                return false
            case .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .resourceUnavailable,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed,
                 .secureConnectionFailed:
                return true
            default:
                return false
            }
        }
        if let ollama = error as? OllamaChatProvider.Failure {
            switch ollama {
            case .httpError(let code, _) where code == 404:
                return true
            case .httpError(let code, _) where code == 429:
                return true
            case .httpError(let code, _) where code >= 500:
                return true
            case .httpError, .invalidBaseURL, .ollamaAPIError, .emptyAssistantMessage, .decoding:
                return false
            }
        }
        if let oai = error as? OpenAICompatibleChatProvider.Failure {
            switch oai {
            case .httpError(let code, _) where code == 404:
                return true
            case .httpError(let code, _) where code == 429:
                return true
            case .httpError(let code, _) where code >= 500:
                return true
            case .httpError, .missingAPIKey, .invalidBaseURL, .apiError, .emptyAssistantMessage, .decoding:
                return false
            }
        }
        if let gem = error as? GeminiGoogleAIChatProvider.Failure {
            switch gem {
            case .httpError(let code, _) where code == 404:
                return true
            case .httpError(let code, _) where code == 429:
                return true
            case .httpError(let code, _) where code >= 500:
                return true
            case .httpError, .missingAPIKey, .emptyModel, .invalidModelID, .emptyAssistantMessage, .decoding:
                return false
            }
        }
        if let co = error as? CohereV2ChatProvider.Failure {
            switch co {
            case .httpError(let code, _) where code == 404:
                return true
            case .httpError(let code, _) where code == 429:
                return true
            case .httpError(let code, _) where code >= 500:
                return true
            case .httpError, .missingAPIKey, .emptyModel, .emptyAssistantMessage, .decoding:
                return false
            }
        }
        return false
    }
}

struct ChatProviderRouter: Sendable {
    private let providers: [LLMChatProvider]

    init(providers: [LLMChatProvider]) {
        self.providers = providers.sorted { $0.sortPriority < $1.sortPriority }
    }

    /// One Ollama client per cloud model; `preferredFirstModel` is tried before the rest of the page‑2 catalog.
    static func ollamaCloudRotation(
        baseURL: String,
        apiKey: String,
        preferredFirstModel: String
    ) -> ChatProviderRouter {
        let models = OllamaCloudModelCatalog.rotationOrder(preferredFirst: preferredFirstModel)
        let providers: [OllamaChatProvider] = models.enumerated().map { index, model in
            OllamaChatProvider(
                baseURLString: baseURL,
                model: model,
                apiKey: apiKey,
                sortPriority: index
            )
        }
        return ChatProviderRouter(providers: providers)
    }

    /// Try every provider at `phaseTimeouts[0]` each, then again at `phaseTimeouts[1]` each (timeouts and transport errors move to the next model).
    func completeWithPhasedFailover(
        userText: String,
        phaseTimeouts: [TimeInterval] = [30, 60]
    ) async throws -> (
        text: String,
        usedProviderId: String,
        usedProviderDisplayName: String
    ) {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChatProviderRouterError.emptyPrompt
        }

        var allAttempts: [(id: String, message: String)] = []

        for (phaseIndex, timeout) in phaseTimeouts.enumerated() {
            for provider in providers {
                do {
                    let text = try await provider.complete(userText: trimmed, timeout: timeout)
                    return (text, provider.id, provider.displayName)
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    allAttempts.append((provider.id, "[\(Int(timeout))s phase \(phaseIndex + 1)] \(message)"))
                    if ChatFailover.shouldTryNext(after: error) {
                        continue
                    }
                    throw error
                }
            }
        }

        throw ChatProviderRouterError.allProvidersFailed(attempts: allAttempts)
    }
}
