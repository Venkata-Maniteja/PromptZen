import Foundation

/// Heuristic token estimates for MVP (no bundled tokenizer). Close enough for budgeting;
/// real usage depends on model and tokenizer.
enum TokenEstimator {
    /// Common rule of thumb for GPT-style BPE: ~4 characters per token for English.
    static func estimateTokens(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        let utf8Count = text.utf8.count
        return max(1, Int(ceil(Double(utf8Count) / 4.0)))
    }

    static func costUSD(
        inputTokens: Int,
        outputTokens: Int,
        pricePerMillionInput: Double,
        pricePerMillionOutput: Double
    ) -> Double {
        let inCost = Double(inputTokens) / 1_000_000.0 * pricePerMillionInput
        let outCost = Double(outputTokens) / 1_000_000.0 * pricePerMillionOutput
        return inCost + outCost
    }
}
