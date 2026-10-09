import SwiftUI

/// Поле ввода с подписью в квадратных скобках, как в дизайне.
struct LabeledField: View {
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var emphasized = false
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).bracketLabel()
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: emphasized ? 20 : 17, weight: emphasized ? .medium : .regular, design: mono ? .monospaced : .default))
                .foregroundStyle(AppColor.ink)
                .mnemisNoAutocapitalization()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(emphasized ? AppColor.accent.opacity(0.5) : AppColor.hairline))
    }
}

/// Добавление слова вручную. Работает офлайн: детали можно дополнить позже.
struct AddWordView: View {
    let viewModel: WordsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var lemma: String
    @State private var translation = ""
    @State private var errorMessage: String?

    init(viewModel: WordsViewModel, initialLemma: String) {
        self.viewModel = viewModel
        _lemma = State(initialValue: initialLemma)
    }

    private var canSave: Bool { !lemma.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).foregroundStyle(AppColor.ash).frame(minHeight: 44)
                Spacer()
                Text("New word").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.plain).fontWeight(.semibold)
                    .foregroundStyle(canSave ? AppColor.accent : AppColor.faint)
                    .frame(minHeight: 44).disabled(!canSave)
            }
            .font(.system(size: 16))
            .foregroundStyle(AppColor.ink)

            LabeledField(label: "[ word · english ]", placeholder: "serendipity", text: $lemma, emphasized: true)
                .padding(.top, 8)
            LabeledField(label: "[ translation · optional ]", placeholder: "счастливая случайность", text: $translation)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("i").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.smoke)
                Text("No internet? The word is saved anyway. Details can be added later.")
                    .font(.system(size: 13)).foregroundStyle(AppColor.smoke)
            }
            .padding(.horizontal, 4)

            if let errorMessage {
                Text(errorMessage).font(.system(size: 13)).foregroundStyle(.red)
            }

            Spacer()
            Button(action: save) {
                HStack(spacing: 10) { Text("Add to my words"); Text("→").font(.system(size: 15, design: .monospaced)) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave).opacity(canSave ? 1 : 0.5)
        }
        .padding(20)
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard canSave else { return }
        do {
            try viewModel.addWord(lemma: lemma, translation: translation)
            dismiss()
        } catch WordEditorError.duplicate {
            errorMessage = "This word is already in your list."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
