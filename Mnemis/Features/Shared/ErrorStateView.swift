import SwiftUI

/// Ошибка без паники: показываем, что случилось, и не блокируем остальной интерфейс.
struct ErrorStateView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Something went wrong",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }
}
