import Foundation

/// Experience tier for prompt text: shorter guidance vs deeper technical detail.
enum ExpertiseLevel: String, Codable, CaseIterable, Hashable, Identifiable {
    case beginner
    case senior
    case staff

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .senior: "Senior"
        case .staff: "Staff"
        }
    }
}
