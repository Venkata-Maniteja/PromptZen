import Combine
import Foundation

@MainActor
final class PlaygroundChatSession: ObservableObject {
    @Published private(set) var responseText: String = ""
    @Published private(set) var statusLine: String = ""
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var usedProviderSummary: String?
    /// Per-provider Run chat health for the sidebar dots.
    @Published private(set) var providerStatusByKind: [PlaygroundAIProviderKind: PlaygroundProviderStatusDot]

    private var pendingTask: Task<Void, Never>?

    init() {
        providerStatusByKind = PlaygroundProviderHealthPersistence.loadStatusMap()
    }

    func statusDot(for kind: PlaygroundAIProviderKind) -> PlaygroundProviderStatusDot {
        providerStatusByKind[kind] ?? .none
    }

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
        let provider = configuration.provider
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
                providerStatusByKind = PlaygroundProviderHealthPersistence.recordSuccess(for: provider)
            } catch is CancellationError {
                statusLine = "Cancelled."
            } catch let urlError as URLError where urlError.code == .cancelled {
                statusLine = "Cancelled."
            } catch {
                statusLine = error.localizedDescription
                providerStatusByKind = PlaygroundProviderHealthPersistence.recordFailure(for: provider)
            }

            isRunning = false
            pendingTask = nil
        }
    }
}
