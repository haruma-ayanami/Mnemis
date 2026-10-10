import SwiftUI

/// Поле ввода с подписью в квадратных скобках, как в дизайне.
struct LabeledField: View {
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var emphasized = false
    var mono = false
    /// Длинный текст переносится, поле растёт до шести строк, дальше прокручивается внутри.
    var multiline = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).bracketLabel()
            TextField(placeholder, text: $text, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 1...6 : 1...1)
                .textFieldStyle(.plain)
                .font(.system(size: emphasized ? 20 : 17, weight: emphasized ? .medium : .regular, design: mono ? .monospaced : .default))
                .foregroundStyle(AppColor.ink)
                .mnemisNoAutocapitalization()
                .focused($isFocused)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Касание по всей карточке ставит фокус в поле, а не только по строке текста.
        .contentShape(.rect(cornerRadius: 20))
        .onTapGesture { isFocused = true }
        .background(AppColor.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(emphasized ? AppColor.accent.opacity(0.5) : AppColor.hairline))
    }
}

/// Что добавляем: слово из словаря или идиому (ABOUT.md, раздел 9.1).
enum EntryKind: String, CaseIterable, Identifiable {
    case word
    case idiom

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .word: "Word"
        case .idiom: "Idiom"
        }
    }
}

/// Состояние поиска идиомы в открытом словаре.
private enum IdiomLookupState: Equatable {
    case idle
    case searching
    case found(IdiomEntry)
    case notFound
    case offline
}

/// Добавление записи вручную. Слова работают офлайн и дополняются из источников.
/// Для идиом значение и пример подставляются из Викисловаря, пока пользователь печатает.
struct AddEntryView: View {
    let viewModel: WordsViewModel
    let container: AppContainer
    var onSaved: (EntryKind) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var kind: EntryKind
    @State private var primary: String
    @State private var secondary = ""
    @State private var example = ""
    @State private var errorMessage: String?
    @State private var lookup: IdiomLookupState = .idle
    /// Значение, подставленное из словаря. Пока пользователь его не менял, новая находка может его заменить.
    @State private var autoFilledMeaning: String?

    init(viewModel: WordsViewModel, container: AppContainer, initialLemma: String, initialKind: EntryKind = .word, onSaved: @escaping (EntryKind) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.container = container
        self.onSaved = onSaved
        _kind = State(initialValue: initialKind)
        _primary = State(initialValue: initialLemma)
    }

    private var canSave: Bool {
        let hasPrimary = !primary.trimmingCharacters(in: .whitespaces).isEmpty
        return kind == .word ? hasPrimary : hasPrimary && !secondary.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(PressScaleStyle()).foregroundStyle(AppColor.ash).frame(minHeight: 44)
                Spacer()
                Text(kind == .word ? "New word" : "New idiom")
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.opacity)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(PressScaleStyle()).fontWeight(.semibold)
                    .foregroundStyle(canSave ? AppColor.accent : AppColor.faint)
                    .frame(minHeight: 44).disabled(!canSave)
            }
            .font(.system(size: 16))
            .foregroundStyle(AppColor.ink)

            KindPicker(selection: $kind)
                .padding(.top, 4)

            // Поля прокручиваются: длинное значение или пример не выталкивают кнопку за экран.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    fields

                    if kind == .idiom {
                        lookupStatus
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("i").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.smoke)
                            Text("No internet? The word is saved anyway. Details can be added later.")
                                .font(.system(size: 13)).foregroundStyle(AppColor.smoke)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 13)).foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Button(action: save) {
                HStack(spacing: 10) {
                    Text(kind == .word ? "Add to my words" : "Add to my idioms")
                    Text("→").font(.system(size: 15, design: .monospaced))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave).opacity(canSave ? 1 : 0.5)
        }
        .padding(20)
        .animation(.snappy(duration: 0.28), value: kind)
        .animation(.snappy(duration: 0.28), value: lookup)
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task(id: LookupKey(kind: kind, text: primary)) { await lookUpIdiom() }
    }

    @ViewBuilder
    private var fields: some View {
        switch kind {
        case .word:
            LabeledField(label: "[ word · english ]", placeholder: "serendipity", text: $primary, emphasized: true)
                .padding(.top, 4)
            LabeledField(label: "[ translation · optional ]", placeholder: "счастливая случайность", text: $secondary, multiline: true)
        case .idiom:
            LabeledField(label: "[ idiom · english ]", placeholder: "break the ice", text: $primary, emphasized: true)
                .padding(.top, 4)
            LabeledField(label: "[ meaning · русский ]", placeholder: "разрядить обстановку", text: $secondary, multiline: true)
            LabeledField(label: "[ example · optional ]", placeholder: "A joke helped break the ice.", text: $example, multiline: true)
        }
    }

    /// Строка под полями: ищем, нашли в Викисловаре, не нашли или нет сети.
    @ViewBuilder
    private var lookupStatus: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            switch lookup {
            case .searching:
                ProgressView().controlSize(.mini)
                Text("Looking up in Wiktionary…")
            case .found(let entry):
                Text("✓").font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Found in Wiktionary · CC BY-SA").foregroundStyle(AppColor.accent)
                    if let definition = entry.definition {
                        Text(definition).foregroundStyle(AppColor.ash)
                    }
                }
            case .notFound:
                Text("i").font(.system(size: 13, design: .monospaced))
                Text("Not in the open dictionary. Write the meaning yourself.")
            case .offline:
                Text("i").font(.system(size: 13, design: .monospaced))
                Text("No connection. Write the meaning yourself, the idiom is saved offline.")
            case .idle:
                Text("i").font(.system(size: 13, design: .monospaced))
                Text("Type an idiom: meaning and example come from Wiktionary.")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(AppColor.smoke)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ищет идиому после короткой паузы в наборе. Новый ввод отменяет прошлый поиск через `.task(id:)`.
    private func lookUpIdiom() async {
        guard kind == .idiom else { return }
        let text = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.contains(" ") else {
            lookup = .idle
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(450))
            lookup = .searching
            let entry = try await container.idioms.lookup(text)
            guard !Task.isCancelled else { return }
            if let entry {
                lookup = .found(entry)
                apply(entry)
            } else {
                lookup = .notFound
            }
        } catch is CancellationError {
            // Пользователь продолжил печатать.
        } catch {
            lookup = .offline
        }
    }

    /// Подставляет значение и пример, если пользователь не написал свои.
    private func apply(_ entry: IdiomEntry) {
        let meaning = entry.suggestedMeaning
        if secondary.isEmpty || secondary == autoFilledMeaning, !meaning.isEmpty {
            secondary = meaning
            autoFilledMeaning = meaning
        }
        if example.isEmpty, let sample = entry.example {
            example = sample
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            switch kind {
            case .word:
                try viewModel.addWord(lemma: primary, translation: secondary)
            case .idiom:
                try container.wordEditor.addIdiom(text: primary, meaning: secondary, example: example)
            }
            onSaved(kind)
            dismiss()
        } catch WordEditorError.duplicate {
            errorMessage = String(localized: "This word is already in your list.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Ключ для `.task(id:)`: поиск перезапускается при смене вида записи или текста.
private struct LookupKey: Equatable {
    let kind: EntryKind
    let text: String
}

/// Переключатель вида записи: два сегмента на стекле, подложка скользит между ними.
private struct KindPicker: View {
    @Binding var selection: EntryKind
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(EntryKind.allCases) { kind in
                let selected = selection == kind
                Button { withAnimation(Motion.swap) { selection = kind } } label: {
                    Text(kind.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background {
                            if selected {
                                Capsule().fill(AppColor.primary).matchedGeometryEffect(id: "kind-pill", in: pill)
                            }
                        }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .glassCapsule()
    }
}
