import Foundation

/// Prompts use main + sub taxonomy; use stack-agnostic placeholders like `[path]`, `[error]` in bodies.
struct Prompt: Identifiable, Hashable {
    var id: UUID
    var title: String
    /// One string per expertise level; always contains keys for beginner, senior, staff.
    var bodies: [ExpertiseLevel: String]
    var mainCategory: String
    var subcategory: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    var normalizedMainCategory: String {
        LibraryTaxonomy.normalizeMain(mainCategory)
    }

    var normalizedSubcategory: String {
        LibraryTaxonomy.normalizeSub(subcategory)
    }

    /// Single line for IDE export / search.
    var taxonomyDisplayLine: String {
        "\(normalizedMainCategory) › \(normalizedSubcategory)"
    }

    init(
        id: UUID = UUID(),
        title: String,
        bodies: [ExpertiseLevel: String] = [:],
        mainCategory: String,
        subcategory: String,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.mainCategory = mainCategory
        self.subcategory = subcategory
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        var merged: [ExpertiseLevel: String] = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, "") })
        for level in ExpertiseLevel.allCases {
            if let v = bodies[level] {
                merged[level] = v
            }
        }
        self.bodies = merged
    }

    func text(for level: ExpertiseLevel) -> String {
        bodies[level] ?? ""
    }

    mutating func setText(_ string: String, for level: ExpertiseLevel) {
        bodies[level] = string
    }

    /// Text used for library search across all levels.
    var combinedBodyTextForSearch: String {
        ExpertiseLevel.allCases.map { text(for: $0) }.joined(separator: "\n")
    }

    /// True if every level’s body is empty or whitespace-only.
    var allBodiesEffectivelyEmpty: Bool {
        ExpertiseLevel.allCases.allSatisfy { text(for: $0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func emptyForNew(
        mainCategory: String = LibraryTaxonomy.fallbackMain,
        subcategory: String = LibraryTaxonomy.fallbackSub
    ) -> Prompt {
        Prompt(title: "", bodies: [:], mainCategory: mainCategory, subcategory: subcategory, isFavorite: false)
    }
}

extension Prompt: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case mainCategory
        case subcategory
        case isFavorite
        case createdAt
        case updatedAt
        case body
        case bodies
        case category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)

        let decMain = try c.decodeIfPresent(String.self, forKey: .mainCategory)
        let decSub = try c.decodeIfPresent(String.self, forKey: .subcategory)
        if decMain != nil || decSub != nil {
            mainCategory = LibraryTaxonomy.normalizeMain(decMain ?? "")
            subcategory = LibraryTaxonomy.normalizeSub(decSub ?? "")
            isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        } else if let legacyCat = try c.decodeIfPresent(String.self, forKey: .category) {
            mainCategory = LibraryTaxonomy.fallbackMain
            subcategory = legacyCat
            isFavorite = false
        } else {
            mainCategory = LibraryTaxonomy.fallbackMain
            subcategory = LibraryTaxonomy.fallbackSub
            isFavorite = false
        }

        if let decoded = try c.decodeIfPresent([ExpertiseLevel: String].self, forKey: .bodies) {
            var merged: [ExpertiseLevel: String] = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, "") })
            for level in ExpertiseLevel.allCases {
                if let v = decoded[level] {
                    merged[level] = v
                }
            }
            bodies = merged
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .body) {
            bodies = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, legacy) })
        } else {
            bodies = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, "") })
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(mainCategory, forKey: .mainCategory)
        try c.encode(subcategory, forKey: .subcategory)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(bodies, forKey: .bodies)
    }
}
