import SwiftUI
import UIKit

/// «Open in Dictionary» (холст: Word-Details). Видна всегда: если статьи нет,
/// системное окно словаря само покажет, что определение не найдено.
/// Статью показывает системное окно; её текст в приложение не копируется.
struct DictionaryLinkButton: View {
    let term: String
    /// Размер подписи и высота нажимаемой области: на карточках сессии 14 pt и 44 pt, в карточке слова 13 pt и 32 pt.
    var fontSize: CGFloat = 13
    var minHeight: CGFloat = 32

    @State private var isShowing = false

    var body: some View {
        Button { isShowing = true } label: {
            HStack(spacing: 5) {
                Text("Open in Dictionary")
                Image(systemName: "arrow.up.right")
            }
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(AppColor.accent)
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .sheet(isPresented: $isShowing) {
            SystemDictionary(term: term)
                .ignoresSafeArea()
        }
    }
}

/// Системный словарь: UIReferenceLibraryViewController сам показывает статью и её навигацию.
private struct SystemDictionary: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}
