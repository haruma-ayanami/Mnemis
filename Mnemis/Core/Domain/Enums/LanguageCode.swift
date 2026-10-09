import Foundation

/// Код языка. В MVP используется пара `en` → `ru` (ABOUT.md, раздел 1).
enum LanguageCode: String, Codable, CaseIterable, Sendable {
    case en
    case ru
}
