import Foundation

private struct PlaygroundProviderHealthRecord: Codable, Equatable {
    var hasEverSucceeded: Bool = false
    var lastFailed: Bool = false
}

enum PlaygroundProviderHealthPersistence {
    private static let key = "PromptZen.playgroundProviderHealth.v1"

    private static func loadRecords() -> [String: PlaygroundProviderHealthRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: PlaygroundProviderHealthRecord].self, from: data)) ?? [:]
    }

    private static func saveRecords(_ map: [String: PlaygroundProviderHealthRecord]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func dot(for kind: PlaygroundAIProviderKind, records: [String: PlaygroundProviderHealthRecord]) -> PlaygroundProviderStatusDot {
        let r = records[kind.rawValue] ?? PlaygroundProviderHealthRecord()
        if r.lastFailed { return .lastFailed }
        if r.hasEverSucceeded { return .verified }
        return .none
    }

    static func loadStatusMap() -> [PlaygroundAIProviderKind: PlaygroundProviderStatusDot] {
        let records = loadRecords()
        return Dictionary(uniqueKeysWithValues: PlaygroundAIProviderKind.allCases.map { kind in
            (kind, dot(for: kind, records: records))
        })
    }

    @discardableResult
    static func recordSuccess(for provider: PlaygroundAIProviderKind) -> [PlaygroundAIProviderKind: PlaygroundProviderStatusDot] {
        var records = loadRecords()
        let k = provider.rawValue
        var r = records[k] ?? PlaygroundProviderHealthRecord()
        r.hasEverSucceeded = true
        r.lastFailed = false
        records[k] = r
        saveRecords(records)
        return loadStatusMap()
    }

    @discardableResult
    static func recordFailure(for provider: PlaygroundAIProviderKind) -> [PlaygroundAIProviderKind: PlaygroundProviderStatusDot] {
        var records = loadRecords()
        let k = provider.rawValue
        var r = records[k] ?? PlaygroundProviderHealthRecord()
        r.lastFailed = true
        records[k] = r
        saveRecords(records)
        return loadStatusMap()
    }
}
