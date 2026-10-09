import SwiftUI

/// Редактирование переводов по частям речи, определения и транскрипции. Пользовательские правки не перезаписываются API.
/// Лишнюю часть речи убирают кнопкой × у её поля; очищенное поле тоже не сохраняется.
struct EditWordView: View {
    let viewModel: WordDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var meanings: [WordMeaning]
    @State private var definition: String
    @State private var ipa: String

    init(viewModel: WordDetailsViewModel) {
        self.viewModel = viewModel
        let all = viewModel.word.allMeanings
        _meanings = State(initialValue: all.isEmpty ? [WordMeaning(partOfSpeech: viewModel.word.partOfSpeech ?? "", translation: "")] : all)
        _definition = State(initialValue: viewModel.word.definition ?? "")
        _ipa = State(initialValue: viewModel.word.ipa ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(PressScaleStyle()).foregroundStyle(AppColor.ash).frame(minHeight: 44)
                Spacer()
                Text("Edit").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Save") {
                    viewModel.update(meanings: meanings, definition: definition, ipa: ipa)
                    dismiss()
                }
                .buttonStyle(PressScaleStyle()).fontWeight(.semibold).foregroundStyle(AppColor.accent).frame(minHeight: 44)
            }
            .font(.system(size: 16))
            .foregroundStyle(AppColor.ink)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(meanings.enumerated()), id: \.offset) { index, meaning in
                        LabeledField(label: label(for: meaning), placeholder: "translation", text: binding(at: index), emphasized: index == 0, multiline: true)
                            .overlay(alignment: .topTrailing) {
                                if meanings.count > 1 {
                                    Button { withAnimation(Motion.swap) { _ = meanings.remove(at: index) } } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(AppColor.faint)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(PressScaleStyle())
                                    .accessibilityLabel(Text("Remove \(meaning.partOfSpeech) meaning"))
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    LabeledField(label: "[ definition ]", placeholder: "definition", text: $definition, multiline: true)
                    LabeledField(label: "[ ipa ]", placeholder: "/ˈsɛrənˌdɪpɪti/", text: $ipa, mono: true)
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(20)
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func label(for meaning: WordMeaning) -> LocalizedStringKey {
        meaning.partOfSpeech.isEmpty ? "[ translation ]" : "[ translation · \(meaning.partOfSpeech) ]"
    }

    /// Привязка к переводу по индексу, безопасная во время удаления строки.
    private func binding(at index: Int) -> Binding<String> {
        Binding(
            get: { meanings.indices.contains(index) ? meanings[index].translation : "" },
            set: { if meanings.indices.contains(index) { meanings[index].translation = $0 } }
        )
    }
}
