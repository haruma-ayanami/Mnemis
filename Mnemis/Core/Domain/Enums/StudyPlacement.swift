import Foundation

/// Куда пользователь вручную отправил ещё не начатое слово (холст: Word-Study).
enum StudyPlacement: String, CaseIterable, Identifiable, Sendable {
    /// В колоду на сегодня, сверх дневного лимита.
    case today
    /// Только в упражнения Practice: расписание повторений не затрагивается.
    case practice
    /// Начать изучение: первое повторение завтра.
    case later

    var id: String { rawValue }
}
