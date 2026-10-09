import OSLog

/// Категории логов. Пользовательских данных в логах не пишем.
enum Log {
    private static let subsystem = "haruma.Mnemis"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let learning = Logger(subsystem: subsystem, category: "learning")
}
