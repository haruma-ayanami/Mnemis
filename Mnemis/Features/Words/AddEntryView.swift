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
    /// Метка «auto» справа от подписи: значение подставил словарь и его можно править.
    var badge: LocalizedStringKey?
    var fontSize: CGFloat?
    var weight: Font.Weight?
    var verticalPadding: CGFloat = 12

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).bracketLabel()
                Spacer(minLength: 8)
                if let badge { AutoBadge(text: badge) }
            }
            TextField(placeholder, text: $text, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 1...6 : 1...1)
                .textFieldStyle(.plain)
                .font(.system(
                    size: fontSize ?? (emphasized ? 20 : 17),
                    weight: weight ?? (emphasized ? .medium : .regular),
                    design: mono ? .monospaced : .default
                ))
                .foregroundStyle(AppColor.ink)
                .mnemisNoAutocapitalization()
                .focused($isFocused)
        }
        .padding(.horizontal, 16).padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Касание по всей карточке ставит фокус в поле, а не только по строке текста.
        .contentShape(.rect(cornerRadius: 20))
        .onTapGesture { isFocused = true }
        .background(AppColor.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(emphasized ? AppColor.accent.opacity(0.5) : AppColor.hairline))
    }
}

/// Метка «auto»: поле заполнено из словаря.
struct AutoBadge: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(AppColor.accent)
            .lineLimit(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.hairline))
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

/// Добавление слова или идиомы тремя шагами: слово, детали, проверка (холст: Add-Word, Add-Word-Details, Add-Word-Review).
/// После «Add» запись сразу открывается своей карточкой, там и выбирают, когда её учить.
struct AddEntryView: View {
    let container: AppContainer
    /// Вызывается, когда нужно открыть карточку: новой записи или уже существующей.
    var onOpen: (Word) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var model: AddEntryViewModel
    @State private var errorMessage: String?
    @FocusState private var wordFocused: Bool

    init(container: AppContainer, initialLemma: String, initialKind: EntryKind = .word, onOpen: @escaping (Word) -> Void = { _ in }) {
        self.container = container
        self.onOpen = onOpen
        _model = State(initialValue: AddEntryViewModel(container: container, kind: initialKind, text: initialLemma))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            progress
            stepCaption

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch model.step {
                    case .word: wordStep
                    case .details: detailsStep
                    case .review: reviewStep
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 13)).foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollsToDismissKeyboard()

            Button(action: advance) {
                HStack(spacing: 10) {
                    Text(model.isLastStep ? (model.kind == .word ? "Add to my words" : "Add to my idioms") : "Continue")
                    Text("→").font(.system(size: 15, design: .monospaced))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.canContinue).opacity(model.canContinue ? 1 : 0.5)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
        .dismissesKeyboard()
        .dismissesKeyboardBeforeSheet()
        .animation(.snappy(duration: 0.28), value: model.step)
        .animation(.snappy(duration: 0.28), value: model.lookup)
        .animation(.snappy(duration: 0.28), value: model.kind)
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task(id: LookupKey(kind: model.kind, text: model.text)) { await model.search() }
        .onChange(of: model.text) { model.textChanged() }
        .onAppear { if model.text.isEmpty { wordFocused = true } }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            Group {
                if model.isFirstStep {
                    Button("Cancel") { dismiss() }.foregroundStyle(AppColor.ash)
                } else {
                    Button {
                        withAnimation(Motion.swap) { model.back() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium))
                            Text("Back")
                        }
                    }
                    .foregroundStyle(AppColor.ash)
                }
            }
            .buttonStyle(PressScaleStyle())
            .frame(minWidth: 64, minHeight: 44, alignment: .leading)

            Spacer()
            Text(LocalizedStringKey(model.title)).font(.system(size: 17, weight: .semibold))
            Spacer()
            Text("\(model.step.rawValue.formatted(.number.precision(.integerLength(2)))) / 03")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(AppColor.ink)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(AddEntryViewModel.Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= model.step.rawValue ? AppColor.accent : AppColor.hairline)
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(model.step.rawValue) of 3"))
    }

    private var stepCaption: some View {
        let label: LocalizedStringKey
        let hint: LocalizedStringKey
        switch model.step {
        case .word: (label, hint) = ("[ word ]", "type it, we look it up")
        case .details: (label, hint) = ("[ details ]", "same order as the card")
        case .review: (label, hint) = ("[ review ]", "check it, the card opens next")
        }
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).bracketLabel(AppColor.accent)
            Text(hint).font(.system(size: 13)).foregroundStyle(AppColor.smoke)
        }
        .padding(.top, 2)
    }

    // MARK: - Шаг 1: слово

    @ViewBuilder
    private var wordStep: some View {
        KindPicker(selection: Binding(get: { model.kind }, set: { model.setKind($0) }))

        LabeledField(
            label: model.kind == .word ? "[ word · english ]" : "[ idiom · english ]",
            placeholder: model.kind == .word ? "serendipity" : "break the ice",
            text: $model.text, emphasized: true, fontSize: 28, weight: .semibold, verticalPadding: 14
        )
        .focused($wordFocused)

        foundCard
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private var foundCard: some View {
        if let existing = model.existing {
            noteCard(title: "[ already in your list ]", message: "This entry is already in your vocabulary. Open it instead.") {
                Button("Open") { open(existing) }
                    .buttonStyle(PressScaleStyle())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.onPrimary)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(AppColor.primary, in: .capsule)
            }
        } else {
            switch model.lookup {
            case .idle:
                EmptyView()
            case .searching:
                noteCard(title: "[ looking up in wiktionary… ]", message: nil) { ProgressView().controlSize(.small) }
            case .found:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedStringKey(model.foundLabel)).bracketLabel()
                        Spacer()
                        Text("✓ found").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.accent)
                    }
                    VStack(spacing: 8) {
                        ForEach(model.foundRows) { row in
                            HStack(spacing: 8) {
                                Text(row.isFound ? "✓" : "–")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(row.isFound ? AppColor.accent : AppColor.faint)
                                Text(LocalizedStringKey(row.title)).font(.system(size: 14)).foregroundStyle(AppColor.ash)
                                Spacer(minLength: 8)
                                Text(row.value)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(AppColor.smoke)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Text(model.sourceLine).font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColor.smoke)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.surface, in: .rect(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColor.hairline))
            case .notFound:
                noteCard(title: "[ not found ]", message: "Not in Wiktionary. You can fill in the details yourself.") { EmptyView() }
            case .offline:
                noteCard(title: "[ no connection ]", message: "Fill in the details yourself. The entry is saved offline.") { EmptyView() }
            }
        }
    }

    private func noteCard<Accessory: View>(title: LocalizedStringKey, message: LocalizedStringKey?, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).bracketLabel()
                if let message {
                    Text(message).font(.system(size: 14)).foregroundStyle(AppColor.ash)
                }
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColor.hairline))
    }

    // MARK: - Шаг 2: детали

    @ViewBuilder
    private var detailsStep: some View {
        if model.kind == .word {
            LabeledField(
                label: "[ ipa ]", placeholder: "/ˈsɛrənˌdɪpɪti/", text: $model.ipa, mono: true,
                badge: model.ipaIsAuto ? "auto · wiktionary" : nil, fontSize: 16, weight: .regular
            )
            partOfSpeechBox
        }
        levelBox
        LabeledField(
            label: model.kind == .word ? "[ translation ]" : "[ meaning · русский ]",
            placeholder: model.kind == .word ? "счастливая случайность" : "разрядить обстановку",
            text: $model.translation, multiline: true,
            badge: model.translationIsAuto ? "auto" : nil, fontSize: 19, weight: .medium
        )
        LabeledField(
            label: "[ definition ]", placeholder: "definition", text: $model.definition, multiline: true,
            badge: model.definitionIsAuto ? "auto" : nil, fontSize: 16, weight: .regular
        )
    }

    private var partOfSpeechBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("[ part of speech ]").bracketLabel()
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(AddEntryViewModel.partsOfSpeech, id: \.self) { part in
                        let selected = model.partOfSpeech == part
                        Button { model.select(partOfSpeech: part) } label: {
                            Text(part)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                                .padding(.horizontal, 14).frame(height: 36)
                                .background(selected ? AppColor.primary : Color.clear, in: .capsule)
                                .overlay(Capsule().stroke(selected ? AppColor.primary : AppColor.hairline))
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColor.hairline))
    }

    private var levelBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("[ level ]").bracketLabel()
            HStack(spacing: 6) {
                ForEach(AddEntryViewModel.levels, id: \.self) { value in
                    let selected = model.level == value
                    Button { model.selectLevel(value) } label: {
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

    // MARK: - Шаг 3: проверка

    @ViewBuilder
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.trimmedText)
                .font(.system(size: model.kind == .word ? 36 : 30, weight: .semibold))
                .tracking(-1.1)
                .lineSpacing(0)
            if !model.previewMeta.isEmpty {
                Text(model.previewMeta).font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
            }
            if !model.previewPills.isEmpty {
                FlowPills(items: model.previewPills)
            }
            if !model.translation.isEmpty {
                Text(model.translation).font(.system(size: 20, weight: .medium)).padding(.top, 4)
            }
            if !model.definition.isEmpty {
                Text(model.definition).font(.system(size: 14)).foregroundStyle(AppColor.ash)
            }
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .cornerMarks()
        .accessibilityElement(children: .combine)

        LabeledField(
            label: "[ example · optional ]", placeholder: "an example sentence", text: $model.example,
            multiline: true, fontSize: 16, weight: .regular
        )

        if model.showsSuggestion, let suggestion = model.suggestion {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("suggested")
                        .font(.system(size: 11, design: .monospaced)).tracking(0.9).textCase(.uppercase)
                        .foregroundStyle(AppColor.accent)
                    Text(suggestion).font(.system(size: 14)).foregroundStyle(AppColor.ash)
                }
                Spacer(minLength: 8)
                Button("Use") { model.useSuggestion() }
                    .buttonStyle(PressScaleStyle())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.onPrimary)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(AppColor.primary, in: .capsule)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColor.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .transition(.opacity)
        }
    }

    // MARK: - Действия

    private func advance() {
        guard model.canContinue else { return }
        if model.isLastStep {
            save()
        } else {
            wordFocused = false
            withAnimation(Motion.swap) { model.next() }
        }
    }

    private func save() {
        do {
            let word = try model.save()
            onOpen(word)
            dismiss()
        } catch WordEditorError.duplicate {
            errorMessage = String(localized: "This word is already in your list.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func open(_ word: Word) {
        onOpen(word)
        dismiss()
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
