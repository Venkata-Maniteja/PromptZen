import Foundation

/// A single chat backend (local or remote). Lower `sortPriority` is tried first.
protocol LLMChatProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var sortPriority: Int { get }

    func complete(userText: String, timeout: TimeInterval) async throws -> String
}

enum ChatProviderRouterError: Error, LocalizedError {
    case allProvidersFailed(attempts: [(id: String, message: String)])
    case emptyPrompt

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Enter some text to send."
        case .allProvidersFailed(let attempts):
            let lines = attempts.map { "\($0.id): \($0.message)" }.joined(separator: "\n")
            return "All providers failed:\n\(lines)"
        }
    }
}
