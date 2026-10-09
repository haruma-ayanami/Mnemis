import Foundation

/// Нормализация для поиска: регистр и пробелы. Исходное написание не меняется (ARCHITECTURE.md, раздел 10).
enum TextNormalizer {
    static func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}
