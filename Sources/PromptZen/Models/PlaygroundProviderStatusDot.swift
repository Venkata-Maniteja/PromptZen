import Foundation

/// Sidebar indicator for a Playground provider’s last **Run chat** outcome.
enum PlaygroundProviderStatusDot: Equatable, Sendable {
    /// No successful run recorded yet (or never run).
    case none
    /// At least one successful API run, and the last run did not fail.
    case verified
    /// The most recent Run chat ended in an error (cancellation does not count).
    case lastFailed
}
