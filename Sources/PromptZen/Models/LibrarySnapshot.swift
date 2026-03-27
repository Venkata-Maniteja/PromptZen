import Foundation

/// Root JSON document for `prompts.json` (v2+).
struct LibrarySnapshot: Codable, Equatable {
    var version: Int
    var prompts: [Prompt]
    var userMainCategories: [String]
    var userSubcategoriesByMain: [String: [String]]

    init(
        version: Int = 2,
        prompts: [Prompt] = [],
        userMainCategories: [String] = [],
        userSubcategoriesByMain: [String: [String]] = [:]
    ) {
        self.version = version
        self.prompts = prompts
        self.userMainCategories = userMainCategories
        self.userSubcategoriesByMain = userSubcategoriesByMain
    }

    enum CodingKeys: String, CodingKey {
        case version
        case prompts
        case userMainCategories
        case userSubcategoriesByMain
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 2
        prompts = try c.decodeIfPresent([Prompt].self, forKey: .prompts) ?? []
        userMainCategories = try c.decodeIfPresent([String].self, forKey: .userMainCategories) ?? []
        userSubcategoriesByMain = try c.decodeIfPresent([String: [String]].self, forKey: .userSubcategoriesByMain) ?? [:]
    }
}
