import SwiftUI
import Observation

/// Одна идиома: значение, примеры, заметка и отметка «знаю / учу» (ABOUT.md, раздел 9.1).
@Observable
@MainActor
final class IdiomDetailsViewModel {
    private(set) var phrase: Phrase
    private(set) var errorMessage: String?

    private let container: AppContainer
    private let onChange: () -> Void

    init(phrase: Phrase, container: AppContainer, onChange: @escaping () -> Void) {
        self.phrase = phrase
        self.container = container
        self.onChange = onChange
    }

    func reload() {
        phrase = (try? container.phrases.phrase(id: phrase.id)) ?? phrase
    }

    func setKnown(_ known: Bool) { perform { try container.phraseEditor.setKnown(known, for: phrase) } }
    func addExample(_ sentence: String) { perform { try container.phraseEditor.addExample(sentence, to: phrase) } }
    func removeExample(at index: Int) { perform { try container.phraseEditor.removeExample(at: index, from: phrase) } }
    func saveNote(_ note: String) { perform { try container.phraseEditor.setNote(note, for: phrase) } }

    func delete() {
        do {
            try container.phraseEditor.delete(id: phrase.id)
            onChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var editor: PhraseEditor { container.phraseEditor }

    func edited() {
        reload()
        onChange()
    }

    private func perform(_ action: () throws -> Phrase) {
        do {
            phrase = try action()
            errorMessage = nil
            onChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Карточка идиомы, устроенная как карточка слова: заголовок, статус, значение, примеры, заметка, действия.
struct IdiomDetailsView: View {
    @State private var viewModel: IdiomDetailsViewModel
    @State private var newExample = ""
    @State private var note: String
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    init(phrase: Phrase, container: AppContainer, onChange: @escaping () -> Void) {
        _viewModel = State(initialValue: IdiomDetailsViewModel(phrase: phrase, container: container, onChange: onChange))
        _note = State(initialValue: phrase.note ?? "")
    }

    private var phrase: Phrase { viewModel.phrase }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            DotGridBackdrop().frame(height: 300).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    header.screenEntrance()
                    statusCard.screenEntrance(delay: 0.04)
                    meaning.screenEntrance(delay: 0.08)
                    examples.screenEntrance(delay: 0.12)
                    noteSection.screenEntrance(delay: 0.16)
                    deleteButton
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .mnemisNavigationBarHidden()
        .sheet(isPresented: $isEditing, onDismiss: viewModel.edited) {
            EditPhraseView(editor: viewModel.editor, phrase: phrase)
        }
    }

    private var topBar: some View {
        HStack {
            RoundGlassButton(systemImage: "chevron.left", label: "Back to Idioms") { dismiss() }
            Spacer()
            Button { isEditing = true } label: {
                Text("Edit").font(.system(size: 15, weight: .medium)).foregroundStyle(AppColor.ink)
                    .padding(.horizontal, 18).frame(minHeight: 44)
            }
            .buttonStyle(PressScaleStyle())
            .glassCapsule()
        }
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text(phrase.text)
                    .font(.system(size: 38, weight: .semibold)).tracking(-1.2)
                    .foregroundStyle(AppColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                SpeakButton(text: phrase.text)
            }
            FlowPills(items: ["idiom", phrase.isKnown ? "known" : "learning", "yours"])
        }
        .padding(.top, 6)
    }

    /// «Знаю / учу»: выученные идиомы реже попадают в идиому дня.
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(phrase.isKnown ? AppColor.fill : .clear)
                    .overlay(Circle().stroke(phrase.isKnown ? .clear : AppColor.smoke, lineWidth: 1.5))
                    .frame(width: 10, height: 10)
                Text(phrase.isKnown ? "You know this idiom" : "In your study list")
                    .font(.system(size: 16, weight: .medium))
                    .contentTransition(.opacity)
                Spacer()
                Text(phrase.isKnown ? "✓" : "▮▯▯▯▯")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppColor.accent)
            }
            KnownToggle(isKnown: phrase.isKnown) { viewModel.setKnown($0) }
            Text(phrase.isKnown ? "It rarely shows up as the idiom of the day." : "It shows up in Today as the idiom of the day.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 22).padding(.vertical, 20)
        .glassCard()
        .cornerMarks()
        .animation(Motion.swap, value: phrase.isKnown)
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[ meaning ]").bracketLabel()
            Text(phrase.meaning)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 4)
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("[ examples ]").bracketLabel()
            if let example = phrase.example {
                exampleRow(tag: "ex.", text: example)
            }
            ForEach(Array(phrase.userExamples.enumerated()), id: \.offset) { index, example in
                exampleRow(tag: "you", text: example)
                    .contextMenu {
                        Button(role: .destructive) { viewModel.removeExample(at: index) } label: {
                            Label("Delete example", systemImage: "trash")
                        }
                    }
            }
            HStack(alignment: .bottom) {
                TextField("Add your example", text: $newExample, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.ink)
                Button("Add", action: addExample)
                    .buttonStyle(PressScaleStyle())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(newExample.trimmingCharacters(in: .whitespaces).isEmpty ? AppColor.faint : AppColor.accent)
                    .disabled(newExample.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppColor.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .padding(.horizontal, 4)
    }

    private func exampleRow(tag: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(tag)
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                .frame(width: 34, alignment: .leading)
            Text(highlighted(text)).font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[ note ]").bracketLabel()
            TextField("Where you heard it, how to use it", text: $note, axis: .vertical)
                .lineLimit(1...8)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(AppColor.ink)
                .padding(14)
                .glassCard(cornerRadius: 20)
            if note != (phrase.note ?? "") {
                Button("Save note") { viewModel.saveNote(note) }
                    .buttonStyle(PressScaleStyle()).font(.system(size: 14, weight: .medium)).foregroundStyle(AppColor.accent)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
        .animation(Motion.swap, value: note == (phrase.note ?? ""))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.delete()
            dismiss()
        } label: {
            Text("Delete idiom").frame(maxWidth: .infinity)
        }
        .buttonStyle(QuietButtonStyle())
        .padding(.top, 4)
    }

    private func addExample() {
        viewModel.addExample(newExample)
        newExample = ""
    }

    /// Подсвечивает первое слово идиомы внутри примера, как слово в примерах словаря.
    private func highlighted(_ sentence: String) -> AttributedString {
        var text = AttributedString(sentence)
        text.foregroundColor = AppColor.ink
        if let range = text.range(of: phrase.text, options: .caseInsensitive) {
            text[range].foregroundColor = AppColor.accent
        }
        return text
    }
}

/// Два сегмента «Still learning | I know it» со скользящей подложкой.
private struct KnownToggle: View {
    let isKnown: Bool
    let onChange: (Bool) -> Void
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            segment("Still learning", value: false)
            segment("I know it", value: true)
        }
        .padding(4)
        .glassCapsule()
    }

    private func segment(_ title: LocalizedStringKey, value: Bool) -> some View {
        let selected = isKnown == value
        return Button { withAnimation(Motion.swap) { onChange(value) } } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background {
                    if selected {
                        Capsule().fill(AppColor.primary).matchedGeometryEffect(id: "known-pill", in: pill)
                    }
                }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Правка текста, значения и примера идиомы. Длинные поля переносятся и растут, форма прокручивается.
struct EditPhraseView: View {
    let editor: PhraseEditor
    let phrase: Phrase

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var meaning: String
    @State private var example: String
    @State private var errorMessage: String?

    init(editor: PhraseEditor, phrase: Phrase) {
        self.editor = editor
        self.phrase = phrase
        _text = State(initialValue: phrase.text)
        _meaning = State(initialValue: phrase.meaning)
        _example = State(initialValue: phrase.example ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(PressScaleStyle()).foregroundStyle(AppColor.ash).frame(minHeight: 44)
                Spacer()
                Text("Edit idiom").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(PressScaleStyle()).fontWeight(.semibold).foregroundStyle(AppColor.accent)
                    .frame(minHeight: 44)
            }
            .font(.system(size: 16))
            .foregroundStyle(AppColor.ink)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LabeledField(label: "[ idiom · english ]", placeholder: "", text: $text, emphasized: true, multiline: true)
                    LabeledField(label: "[ meaning · русский ]", placeholder: "", text: $meaning, multiline: true)
                    LabeledField(label: "[ example · optional ]", placeholder: "", text: $example, multiline: true)
                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 13)).foregroundStyle(.red)
                    }
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

    private func save() {
        var updated = phrase
        updated.text = text
        updated.meaning = meaning
        updated.example = example
        do {
            try editor.update(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
