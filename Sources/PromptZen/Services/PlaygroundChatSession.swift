import Combine
import Foundation

@MainActor
final class PlaygroundChatSession: ObservableObject {
    @Published private(set) var responseText: String = ""
    @Published private(set) var statusLine: String = ""
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var usedProviderSummary: String?

    private var pendingTask: Task<Void, Never>?

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        if isRunning {
            isRunning = false
            statusLine = "Cancelled."
        }
    }

    func run(prompt: String, configuration: PlaygroundChatConfiguration) {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor in
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                statusLine = "Enter text to send."
                return
            }

            isRunning = true
            usedProviderSummary = nil

            let (router, phaseTimeouts, line) = ChatProviderRouter.forPlayground(configuration: configuration)
            statusLine = line

            do {
                let result = try await router.completeWithPhasedFailover(
                    userText: trimmed,
                    phaseTimeouts: phaseTimeouts
                )
                responseText = result.text
                usedProviderSummary = "Model: \(result.usedProviderDisplayName)"
                statusLine = "Done."
            } catch is CancellationError {
                statusLine = "Cancelled."
            } catch {
                statusLine = error.localizedDescription
            }

            isRunning = false
            pendingTask = nil
        }
    }
}
