import Combine
import Foundation

enum SidebarSelection: Hashable {
    case library(main: String, sub: String)
    case favorites(main: String, sub: String)

    var main: String {
        switch self {
        case .library(let m, _), .favorites(let m, _):
            return m
        }
    }

    var sub: String {
        switch self {
        case .library(_, let s), .favorites(_, let s):
            return s
        }
    }
}

/// Column 1: which main is active under Library vs Favorites.
enum TaxonomyMainPick: Hashable {
    case library(String)
    case favorites(String)

    var main: String {
        switch self {
        case .library(let m), .favorites(let m):
            return m
        }
    }

    func matches(_ tax: SidebarSelection) -> Bool {
        switch (self, tax) {
        case (.library(let m1), .library(let m2, _)):
            return m1.lowercased() == m2.lowercased()
        case (.favorites(let m1), .favorites(let m2, _)):
            return m1.lowercased() == m2.lowercased()
        default:
            return false
        }
    }
}

@MainActor
final class PromptStore: ObservableObject {
    @Published private(set) var prompts: [Prompt] = []
    @Published var selectedPromptID: UUID?
    @Published var searchText: String = ""
    @Published var selectedTaxonomy: SidebarSelection?
    @Published var selectedTaxonomyMain: TaxonomyMainPick?
    @Published private(set) var userMainCategories: [String] = []
    @Published private(set) var userSubcategoriesByMain: [String: [String]] = [:]

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

    var allMainCategoriesOrdered: [String] {
        LibraryTaxonomy.mergedMainCategories(userMainCategories: userMainCategories, prompts: prompts)
    }

    func subcategories(for main: String) -> [String] {
        LibraryTaxonomy.subcategories(
            for: main,
            userSubcategoriesByMain: userSubcategoriesByMain,
            prompts: prompts
        )
    }

    /// Mains that have at least one favorite prompt (stable order from `allMainCategoriesOrdered`).
    var favoriteMainsOrdered: [String] {
        let withFavorite = Set(
            prompts.filter(\.isFavorite).map { $0.normalizedMainCategory.lowercased() }
        )
        return allMainCategoriesOrdered.filter { withFavorite.contains($0.lowercased()) }
    }

    func favoriteSubs(for main: String) -> [String] {
        let ml = main.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let subs = Set(
            prompts
                .filter { $0.isFavorite && $0.normalizedMainCategory.lowercased() == ml }
                .map { $0.normalizedSubcategory }
        )
        return subs.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var listedPrompts: [Prompt] {
        guard let sel = selectedTaxonomy else { return [] }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompts
            .filter { p in
                switch sel {
                case .library(let m, let s):
                    guard p.normalizedMainCategory.lowercased() == m.lowercased(),
                          p.normalizedSubcategory.lowercased() == s.lowercased() else { return false }
                case .favorites(let m, let s):
                    guard p.isFavorite,
                          p.normalizedMainCategory.lowercased() == m.lowercased(),
                          p.normalizedSubcategory.lowercased() == s.lowercased() else { return false }
                }
                guard !q.isEmpty else { return true }
                if p.title.localizedCaseInsensitiveContains(q) { return true }
                if p.combinedBodyTextForSearch.localizedCaseInsensitiveContains(q) { return true }
                if p.normalizedMainCategory.localizedCaseInsensitiveContains(q) { return true }
                if p.normalizedSubcategory.localizedCaseInsensitiveContains(q) { return true }
                return false
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Template for New Prompt from current sidebar selection.
    func newPromptDraft() -> Prompt {
        if let sel = selectedTaxonomy {
            return Prompt.emptyForNew(mainCategory: sel.main, subcategory: sel.sub)
        }
        if let pick = selectedTaxonomyMain {
            let main = pick.main
            let subs: [String] = switch pick {
            case .library:
                subcategories(for: main)
            case .favorites:
                favoriteSubs(for: main)
            }
            if let first = subs.first {
                return Prompt.emptyForNew(mainCategory: main, subcategory: first)
            }
            return Prompt.emptyForNew(mainCategory: main, subcategory: LibraryTaxonomy.fallbackSub)
        }
        return Prompt.emptyForNew()
    }

    /// Column 1: pick a main; clears full taxonomy if it no longer matches.
    func selectTaxonomyMain(_ pick: TaxonomyMainPick?) {
        selectedTaxonomyMain = pick
        if let pick, let tax = selectedTaxonomy {
            if !pick.matches(tax) {
                selectedTaxonomy = nil
                selectedPromptID = nil
            }
        } else if pick == nil {
            selectedTaxonomy = nil
            selectedPromptID = nil
        }
    }

    /// Column 2: pick a sub; keeps column 1 in sync.
    func selectTaxonomy(_ tax: SidebarSelection) {
        selectedTaxonomy = tax
        switch tax {
        case .library(let m, _):
            selectedTaxonomyMain = .library(m)
        case .favorites(let m, _):
            selectedTaxonomyMain = .favorites(m)
        }
    }

    func addMainCategory(_ raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let lower = name.lowercased()
        if lower == LibraryTaxonomy.retiredMainCategoryWebDevelopment.lowercased() { return }
        if allMainCategoriesOrdered.contains(where: { $0.lowercased() == lower }) { return }
        userMainCategories.append(name)
        save()
    }

    func addSubcategory(to main: String, name raw: String) {
        let sub = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { return }
        let mainKey = LibraryTaxonomy.normalizeMain(main)
        var list = userSubcategoriesByMain[mainKey] ?? []
        if list.contains(where: { $0.lowercased() == sub.lowercased() }) { return }
        list.append(sub)
        userSubcategoriesByMain[mainKey] = list
        save()
    }

    func toggleFavorite(id: UUID) {
        guard let i = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[i].isFavorite.toggle()
        save()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            prompts = []
            userMainCategories = []
            userSubcategoriesByMain = [:]
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            if let snap = try? decoder.decode(LibrarySnapshot.self, from: data) {
                prompts = snap.prompts
                userMainCategories = snap.userMainCategories
                userSubcategoriesByMain = snap.userSubcategoriesByMain
            } else if let legacy = try? decoder.decode([Prompt].self, from: data) {
                prompts = legacy
                userMainCategories = []
                userSubcategoriesByMain = [:]
                save()
            } else {
                prompts = []
                userMainCategories = []
                userSubcategoriesByMain = [:]
            }
            migrateRetiredWebDevelopmentCategory()
            save()
        } catch {
            prompts = []
            userMainCategories = []
            userSubcategoriesByMain = [:]
        }
    }

    /// Reassign prompts and catalog entries away from removed built-in "Web Development".
    private func migrateRetiredWebDevelopmentCategory() {
        let retired = LibraryTaxonomy.retiredMainCategoryWebDevelopment.lowercased()
        for i in prompts.indices {
            let m = prompts[i].mainCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            if m.lowercased() == retired {
                prompts[i].mainCategory = LibraryTaxonomy.fallbackMain
            }
        }
        userMainCategories.removeAll { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == retired }

        let retiredKeys = userSubcategoriesByMain.keys.filter { $0.lowercased() == retired }
        for oldKey in retiredKeys {
            guard let subs = userSubcategoriesByMain.removeValue(forKey: oldKey) else { continue }
            let otherKey = LibraryTaxonomy.fallbackMain
            var existing = userSubcategoriesByMain[otherKey] ?? []
            for s in subs where !existing.contains(where: { $0.lowercased() == s.lowercased() }) {
                existing.append(s)
            }
            userSubcategoriesByMain[otherKey] = existing
        }
    }

    private func save() {
        do {
            let snap = LibrarySnapshot(
                version: 2,
                prompts: prompts,
                userMainCategories: userMainCategories,
                userSubcategoriesByMain: userSubcategoriesByMain
            )
            let data = try encoder.encode(snap)
            try data.write(to: fileURL, options: [.atomic])
        } catch {}
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
        if selectedPromptID == id {
            selectedPromptID = listedPrompts.first?.id ?? prompts.first?.id
        }
        save()
    }

    func duplicate(id: UUID) {
        guard let original = prompts.first(where: { $0.id == id }) else { return }
        let copy = Prompt(
            title: original.title + " Copy",
            bodies: original.bodies,
            mainCategory: original.mainCategory,
            subcategory: original.subcategory,
            isFavorite: original.isFavorite
        )
        prompts.append(copy)
        selectedPromptID = copy.id
        save()
    }

    /// Select first library folder if none selected (e.g. after load).
    func ensureDefaultTaxonomySelection() {
        if selectedTaxonomyMain == nil, let tax = selectedTaxonomy {
            switch tax {
            case .library(let m, _):
                selectedTaxonomyMain = .library(m)
            case .favorites(let m, _):
                selectedTaxonomyMain = .favorites(m)
            }
        }
        guard selectedTaxonomy == nil else { return }
        let mains = allMainCategoriesOrdered
        guard let firstMain = mains.first else { return }
        let subs = subcategories(for: firstMain)
        guard let firstSub = subs.first else { return }
        selectedTaxonomyMain = .library(firstMain)
        selectedTaxonomy = .library(main: firstMain, sub: firstSub)
    }
}
