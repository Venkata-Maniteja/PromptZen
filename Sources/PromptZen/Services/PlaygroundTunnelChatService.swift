import Foundation

/// Handles `POST /chat` for the Playground web tunnel using the same routing as the in-app Run button.
enum PlaygroundTunnelChatService {
    private static let secretKey = "PromptZen.tunnelWebSecret"

    static func tunnelSecret() -> String {
        UserDefaults.standard.string(forKey: secretKey) ?? ""
    }

    /// Ensures a non-empty secret exists (call when Connect is pressed).
    static func ensureTunnelSecret() -> String {
        let d = UserDefaults.standard
        if let existing = d.string(forKey: secretKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        d.set(fresh, forKey: secretKey)
        return fresh
    }

    static func validateAuthorization(_ headerValue: String?, bodySecret: String?) -> Bool {
        let expected = tunnelSecret().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expected.isEmpty else { return false }

        if let body = bodySecret?.trimmingCharacters(in: .whitespacesAndNewlines), body == expected {
            return true
        }

        guard let h = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty else {
            return false
        }
        let lower = h.lowercased()
        if lower.hasPrefix("bearer ") {
            return String(h.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines) == expected
        }
        return h == expected
    }

    static func completeChat(userMessage: String, authorizationHeader: String?, bodySecret: String?) async throws -> String {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlaygroundTunnelError.emptyMessage
        }
        guard validateAuthorization(authorizationHeader, bodySecret: bodySecret) else {
            throw PlaygroundTunnelError.unauthorized
        }

        let config = PlaygroundUserDefaultsReader.loadChatConfiguration()
        let (router, phaseTimeouts, _) = ChatProviderRouter.forPlayground(configuration: config)
        let result = try await router.completeWithPhasedFailover(userText: trimmed, phaseTimeouts: phaseTimeouts)
        return result.text
    }
}

enum PlaygroundTunnelError: Error, LocalizedError {
    case emptyMessage
    case unauthorized
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .emptyMessage: return "Message is empty."
        case .unauthorized: return "Invalid or missing tunnel secret."
        case .invalidJSON: return "Request body is not valid JSON."
        }
    }
}
