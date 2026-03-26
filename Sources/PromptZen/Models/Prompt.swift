import Foundation

/// Suggested category labels (user-editable): Feature, Debug, Maintenance, Refactor, Testing, Review, Docs, Security, DX.
/// Use stack-agnostic placeholders like `[path]`, `[error]` in prompt bodies.
struct Prompt: Identifiable, Hashable {
    var id: UUID
    var title: String
    /// One string per expertise level; always contains keys for beginner, senior, staff.
    var bodies: [ExpertiseLevel: String]
    var category: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        bodies: [ExpertiseLevel: String] = [:],
        category: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
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

    static func emptyForNew(category: String = "") -> Prompt {
        Prompt(title: "", bodies: [:], category: category)
    }
}

extension Prompt: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case createdAt
        case updatedAt
        case body
        case bodies
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        category = try c.decode(String.self, forKey: .category)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)

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
        try c.encode(category, forKey: .category)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(bodies, forKey: .bodies)
    }
}
