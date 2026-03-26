import Combine
import Foundation

@MainActor
final class PromptStore: ObservableObject {
    @Published private(set) var prompts: [Prompt] = []
    @Published var selectedPromptID: UUID?
    @Published var searchText: String = ""
    @Published var selectedCategory: String? // nil = All

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("PromptZen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("prompts.json")
        load()
    }

    var categories: [String] {
        let trimmed = prompts.map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
        let unique = Set(trimmed.filter { !$0.isEmpty })
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var filteredPrompts: [Prompt] {
        prompts
            .filter { p in
                guard let cat = selectedCategory else { return true }
                return p.category.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(cat) == .orderedSame
            }
            .filter { p in
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return true }
                if p.title.localizedCaseInsensitiveContains(q) { return true }
                if p.combinedBodyTextForSearch.localizedCaseInsensitiveContains(q) { return true }
                if p.category.localizedCaseInsensitiveContains(q) { return true }
                return false
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            prompts = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            prompts = try decoder.decode([Prompt].self, from: data)
            // Rewrite file so legacy `body` key is dropped after migration to `bodies`.
            save()
        } catch {
            prompts = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(prompts)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // MVP: silent fail; could surface an alert later
        }
    }

    func add(_ prompt: Prompt) {
        prompts.append(prompt)
        selectedPromptID = prompt.id
        save()
    }

    func update(_ prompt: Prompt) {
        guard let i = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        var next = prompt
        next.updatedAt = Date()
        prompts[i] = next
        save()
    }

    func delete(id: UUID) {
        prompts.removeAll { $0.id == id }
        if selectedPromptID == id { selectedPromptID = prompts.first?.id }
        save()
    }

    func duplicate(id: UUID) {
        guard let original = prompts.first(where: { $0.id == id }) else { return }
        let copy = Prompt(
            title: original.title + " Copy",
            bodies: original.bodies,
            category: original.category
        )
        prompts.append(copy)
        selectedPromptID = copy.id
        save()
    }
}
