import SwiftUI

/// Редактирование слова (холст: Edit-Word): транскрипция, уровень, переводы по частям речи, определение.
/// Поля «auto» пришли из словаря; правка снимает метку, и словарь её больше не перезаписывает.
/// Лишнюю часть речи убирают кнопкой × у её поля; очищенное поле тоже не сохраняется.
struct EditWordView: View {
    let viewModel: WordDetailsViewModel
    /// Вызывается после удаления: карточка закрывается вместе с формой.
    var onDeleted: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeletion = false
    @State private var meanings: [WordMeaning]
    @State private var definition: String
    @State private var ipa: String
    @State private var level: String?

    init(viewModel: WordDetailsViewModel, onDeleted: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onDeleted = onDeleted
        let all = viewModel.word.allMeanings
        _meanings = State(initialValue: all.isEmpty ? [WordMeaning(partOfSpeech: viewModel.word.partOfSpeech ?? "", translation: "")] : all)
        _definition = State(initialValue: viewModel.word.definition ?? "")
        _ipa = State(initialValue: viewModel.word.ipa ?? "")
        _level = State(initialValue: viewModel.word.level)
    }

    private var word: Word { viewModel.word }
    private var isIdiom: Bool { word.isIdiom }
    /// Значение пришло из словаря и пользователь его не правил.
    private func isAuto(_ field: String, value: String) -> Bool {
        word.licenseID != nil && !value.isEmpty && !word.editedFields.contains(field)
    }

    /// Части речи, которых у слова ещё нет: их предлагает «+ Add part of speech».
    private var availableParts: [String] {
        let used = Set(meanings.map(\.partOfSpeech))
        return AddEntryViewModel.partsOfSpeech.filter { !used.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(PressScaleStyle()).foregroundStyle(AppColor.ash).frame(minHeight: 44)
                Spacer()
                Text("Edit").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Save") {
                    viewModel.update(meanings: meanings, definition: definition, ipa: ipa, level: level)
                    dismiss()
                }
                .buttonStyle(PressScaleStyle()).fontWeight(.semibold).foregroundStyle(AppColor.accent).frame(minHeight: 44)
            }
            .font(.system(size: 16))
            .foregroundStyle(AppColor.ink)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !isIdiom {
                        LabeledField(
                            label: "[ ipa ]", placeholder: "/ˈsɛrənˌdɪpɪti/", text: $ipa, mono: true,
                            badge: isAuto(Word.editedIPA, value: ipa) ? "auto · wiktionary" : nil,
                            fontSize: 16, weight: .regular, verticalPadding: 11
                        )
                    }
                    levelBox
                    ForEach(Array(meanings.enumerated()), id: \.offset) { index, meaning in
                        LabeledField(
                            label: label(for: meaning), placeholder: "translation", text: binding(at: index),
                            multiline: true, fontSize: index == 0 ? 19 : 17, weight: index == 0 ? .medium : .regular, verticalPadding: 11
                        )
                        .padding(.trailing, meanings.count > 1 ? 36 : 0)
                        .overlay(alignment: .topTrailing) {
                            if meanings.count > 1 {
                                Button { withAnimation(Motion.swap) { _ = meanings.remove(at: index) } } label: {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundStyle(AppColor.faint)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(PressScaleStyle())
                                .accessibilityLabel(Text("Remove \(meaning.partOfSpeech) meaning"))
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    if !isIdiom, !availableParts.isEmpty {
                        addPartOfSpeech
                    }
                    LabeledField(
                        label: "[ definition ]", placeholder: "definition", text: $definition, multiline: true,
                        badge: isAuto(Word.editedDefinition, value: definition) ? "auto" : nil,
                        fontSize: 16, weight: .regular, verticalPadding: 11
                    )
                    if word.licenseID != nil {
                        HStack(alignment: .top, spacing: 10) {
                            Text("i").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.accent)
                            Text("Fields marked auto come from the built-in list and Wiktionary. Your edits are never overwritten.")
                                .font(.system(size: 13)).foregroundStyle(AppColor.smoke)
                        }
                        .padding(.horizontal, 4).padding(.top, 2)
                    }
                    if isIdiom, word.origin == .user {
                        Button(role: .destructive) { confirmsDeletion = true } label: {
                            Text("Delete idiom").font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollsToDismissKeyboard()
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
        .dismissesKeyboard()
        .dismissesKeyboardBeforeSheet()
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Delete this idiom?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete idiom", role: .destructive) {
                if viewModel.delete() {
                    dismiss()
                    onDeleted()
                }
            }
        }
    }

    private var levelBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("[ level ]").bracketLabel()
            HStack(spacing: 6) {
                ForEach(AddEntryViewModel.levels, id: \.self) { value in
                    let selected = level == value
                    Button { level = selected ? nil : value } label: {
                        Text(value)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(selected ? AppColor.primary : Color.clear, in: .capsule)
                            .overlay(Capsule().stroke(selected ? AppColor.primary : AppColor.hairline))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColor.hairline))
    }

    /// Пунктирная кнопка: меню с частями речи, которых у слова ещё нет.
    private var addPartOfSpeech: some View {
        Menu {
            ForEach(availableParts, id: \.self) { part in
                Button(part) {
                    withAnimation(Motion.swap) {
                        // Пустая первая строка (слово без перевода) занимает выбранную часть речи.
                        if meanings.count == 1, meanings[0].translation.isEmpty, meanings[0].partOfSpeech.isEmpty {
                            meanings[0].partOfSpeech = part
                        } else {
                            meanings.append(WordMeaning(partOfSpeech: part, translation: ""))
                        }
                    }
                }
            }
        } label: {
            Text("+ Add part of speech")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.ash)
                .padding(.horizontal, 16).frame(height: 40)
                .overlay(Capsule().stroke(AppColor.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
