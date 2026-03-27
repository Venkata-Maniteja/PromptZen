import Foundation

enum LibraryTaxonomy {
    static let fallbackMain = "Other"
    static let fallbackSub = "General"

    static let builtInMainCategories: [String] = [
        "Mobile Development",
        "Design System",
        "Tech Discussions/Spike",
        "Other",
    ]

    /// Mains that do not use the shared default subcategory list (only user-added + subs from prompts).
    private static let mainsWithoutDefaultSubcategoriesLowercased: Set<String> = [
        "design system",
        "tech discussions/spike",
        "other",
    ]

    /// Removed built-in; prompts still on disk are migrated to `Other` on load.
    static let retiredMainCategoryWebDevelopment = "Web Development"

    static func mainOmitsDefaultSubcategoryList(_ main: String) -> Bool {
        mainsWithoutDefaultSubcategoriesLowercased.contains(
            main.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    /// Shared default subcategories (product lifecycle–oriented).
    static let defaultSubcategories: [String] = [
        "Requirements",
        "Research",
        "Spike",
        "Estimation",
        "UX",
        "UI",
        "Design System",
        "Content",
        "Architecture",
        "Implementation",
        "Refactoring",
        "Debugging",
        "Networking",
        "Data",
        "API",
        "Performance",
        "Testing",
        "CI/CD",
        "Code Review",
        "IDE",
        "Simulator",
        "Device",
        "Build",
        "Environment",
        "Security",
        "Accessibility",
        "Localization",
        "Documentation",
        "Observability",
        "Release",
        "Incident Response",
    ]

    static func normalizeMain(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallbackMain : t
    }

    static func normalizeSub(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallbackSub : t
    }

    /// Built-in + user-added + any main appearing on prompts, stable sort (built-in order first, then rest).
    static func mergedMainCategories(
        userMainCategories: [String],
        prompts: [Prompt]
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        func appendUnique(_ name: String) {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            let ck = key.lowercased()
            guard !seen.contains(ck) else { return }
            seen.insert(ck)
            result.append(key)
        }

        for m in builtInMainCategories {
            appendUnique(m)
        }
        for m in userMainCategories {
            appendUnique(m)
        }
        for p in prompts {
            appendUnique(p.normalizedMainCategory)
        }
        return result
    }

    static func subcategories(
        for main: String,
        userSubcategoriesByMain: [String: [String]],
        prompts: [Prompt]
    ) -> [String] {
        let mainNorm = normalizeMain(main)
        var seen = Set<String>()
        var result: [String] = []

        func appendUnique(_ name: String) {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            let ck = key.lowercased()
            guard !seen.contains(ck) else { return }
            seen.insert(ck)
            result.append(key)
        }

        if !mainOmitsDefaultSubcategoryList(mainNorm) {
            for s in defaultSubcategories {
                appendUnique(s)
            }
        }
        if let extra = userSubcategoriesByMain[mainNorm] {
            for s in extra {
                appendUnique(s)
            }
        }
        // Match prompts by case-insensitive main
        for p in prompts where p.normalizedMainCategory.lowercased() == mainNorm.lowercased() {
            appendUnique(p.normalizedSubcategory)
        }
        if mainOmitsDefaultSubcategoryList(mainNorm), result.isEmpty {
            appendUnique(fallbackSub)
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
