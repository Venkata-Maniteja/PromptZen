import Foundation

/// Cloud models from [Ollama cloud search page 2](https://ollama.com/search?c=cloud&page=2), ordered by typical capability (strongest first).
enum OllamaCloudModelCatalog {
    static let searchPage2ModelsInOrder: [String] = [
        "deepseek-v3.1:latest",
        "kimi-k2-thinking:latest",
        "gpt-oss:120b",
        "mistral-large-3:latest",
        "qwen3-coder:30b",
        "minimax-m2.1:latest",
        "kimi-k2:latest",
        "gemma3:latest",
    ]

    /// Puts `preferred` first when non-empty; drops duplicate if it already appears in the catalog.
    static func rotationOrder(preferredFirst: String) -> [String] {
        let p = preferredFirst.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return searchPage2ModelsInOrder }
        let rest = searchPage2ModelsInOrder.filter { $0.caseInsensitiveCompare(p) != .orderedSame }
        return [p] + rest
    }
}
