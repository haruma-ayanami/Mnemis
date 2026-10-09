import SwiftUI

/// Редактирование перевода, определения и транскрипции. Пользовательские правки не перезаписываются API.
struct EditWordView: View {
    let viewModel: WordDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var translation: String
    @State private var definition: String
    @State private var ipa: String

    init(viewModel: WordDetailsViewModel) {
        self.viewModel = viewModel
        _translation = State(initialValue: viewModel.word.translation)
        _definition = State(initialValue: viewModel.word.definition ?? "")
        _ipa = State(initialValue: viewModel.word.ipa ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).foregroundStyle(AppColor.ash).frame(minHeight: 44)
                Spacer()
                Text("Edit").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Save") {
                    viewModel.update(translation: translation, definition: definition, ipa: ipa)
                    dismiss()
                }
                .buttonStyle(.plain).fontWeight(.semibold).foregroundStyle(AppColor.accent).frame(minHeight: 44)
            }
            .font(.system(size: 16))
            .foregroundStyle(AppColor.ink)

            LabeledField(label: "[ translation ]", placeholder: "translation", text: $translation, emphasized: true)
                .padding(.top, 8)
            LabeledField(label: "[ definition ]", placeholder: "definition", text: $definition)
            LabeledField(label: "[ ipa ]", placeholder: "/ˈsɛrənˌdɪpɪti/", text: $ipa, mono: true)
            Spacer()
        }
        .padding(20)
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
