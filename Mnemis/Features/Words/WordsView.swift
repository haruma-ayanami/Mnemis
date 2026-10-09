import SwiftUI

/// Личный словарь: вкладки «Words» и «Idioms», поиск, фильтры по статусам, список со свайпами (ABOUT.md, раздел 15).
struct WordsView: View {
    @State private var viewModel: WordsViewModel
    @State private var phrases: PhrasesViewModel
    @State private var section: WordsSection = .words
    @State private var isAdding = false
    @State private var addKind: EntryKind = .word
    /// Открытая карточка слова: переход без шеврона, как в дизайне строк.
    @State private var openedWord: Word?
    @State private var openedIdiom: Phrase?
    /// Источник «зума»: карточка слова вырастает из строки, форма добавления — из кнопки «+».
    @Namespace private var zoom
    @Namespace private var pill
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: WordsViewModel(container: container))
        _phrases = State(initialValue: PhrasesViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    header
                    sectionPicker.padding(.top, 16)
                    // Разделы въезжают со своей стороны, как сегменты переключателя.
                    switch section {
                    case .words:
                        VStack(alignment: .leading, spacing: 0) {
                            searchField.padding(.top, 14)
                            chips.padding(.top, 12)
                            wordsList
                        }
                        .transition(.asymmetric(insertion: .offset(x: -36).combined(with: .opacity), removal: .opacity))
                    case .idioms:
                        PhrasesListView(viewModel: phrases, zoom: zoom) {
                            addKind = .idiom
                            isAdding = true
                        } onOpen: { phrase in
                            openedIdiom = phrase
                        }
                        .transition(.asymmetric(insertion: .offset(x: 36).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .animation(Motion.swap, value: section)
            }
            .mnemisNavigationBarHidden()
            .navigationDestination(isPresented: Binding(
                get: { openedWord != nil },
                set: { if !$0 { openedWord = nil } }
            )) {
                if let openedWord {
                    WordDetailsView(word: openedWord, container: container, onChange: reloadAll)
                        .navigationTransition(.zoom(sourceID: openedWord.id, in: zoom))
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { openedIdiom != nil },
                set: { if !$0 { openedIdiom = nil } }
            )) {
                if let openedIdiom {
                    IdiomDetailsView(phrase: openedIdiom, container: container, onChange: { phrases.load() })
                        .navigationTransition(.zoom(sourceID: openedIdiom.id, in: zoom))
                }
            }
            .sheet(isPresented: $isAdding, onDismiss: reloadAll) {
                // .id(addKind): начальный вид записи применяется заново при каждом открытии, а не сохраняется от прошлого раза.
                AddEntryView(viewModel: viewModel, container: container, initialLemma: section == .words ? viewModel.query : "", initialKind: addKind) { _ in
                    phrases.load()
                }
                .id(addKind)
                .navigationTransition(.zoom(sourceID: Self.addSource, in: zoom))
            }
            .onAppear(perform: reloadAll)
        }
    }

    private func reloadAll() {
        viewModel.load()
        phrases.load()
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Words").font(.mnemisTitle).tracking(-0.8).foregroundStyle(AppColor.ink)
                Text(subtitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
            }
            Spacer()
            RoundGlassButton(systemImage: "plus", label: section == .words ? "Add word" : "Add idiom") {
                addKind = section == .words ? .word : .idiom
                isAdding = true
            }
            .matchedTransitionSource(id: Self.addSource, in: zoom)
        }
        .padding(.top, 8)
    }

    private static let addSource = "add-entry"

    private var subtitle: String {
        switch section {
        case .words: "\(viewModel.totalCount.formatted()) in your vocabulary"
        case .idioms:
            phrases.totalCount == 1 ? "1 idiom" : "\(phrases.totalCount.formatted()) idioms"
        }
    }

    /// Переключатель «Words | Idioms»: вкладки словаря, как в дизайне.
    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(WordsSection.allCases) { item in
                let selected = section == item
                Button { withAnimation(Motion.swap) { section = item } } label: {
                    HStack(spacing: 7) {
                        Text(item.title)
                        Text(item == .words ? viewModel.totalCount.formatted() : phrases.totalCount.formatted())
                            .font(.system(size: 11, design: .monospaced)).opacity(0.7)
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background {
                        // Подложка выбранного сегмента скользит между ними, а не перескакивает.
                        if selected {
                            Capsule().fill(AppColor.primary).matchedGeometryEffect(id: "section-pill", in: pill)
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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppColor.smoke)
            TextField("Search word, translation, note", text: $viewModel.query)
                .textFieldStyle(.plain)
                .mnemisNoAutocapitalization()
                .foregroundStyle(AppColor.ink)
            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppColor.smoke)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .font(.system(size: 16))
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
        .glassCapsule()
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(nil, "All")
                chip(.learning, "Learning")
                chip(.reviewing, "Reviewing")
                chip(.remembered, "Remembered")
                chip(.known, "Known")
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ status: LearningStatus?, _ title: LocalizedStringKey) -> some View {
        let selected = viewModel.filter == status
        return Button { viewModel.filter = status } label: {
            HStack(spacing: 6) {
                Text(title)
                Text("\(viewModel.count(for: status))")
                    .font(.system(size: 11, design: .monospaced)).opacity(0.7)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
            .padding(.horizontal, 13).frame(minHeight: 36)
            .background(selected ? AppColor.primary : .clear, in: .capsule)
            .overlay(Capsule().stroke(selected ? .clear : AppColor.hairline))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var wordsList: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message)
        case .loaded:
            if viewModel.totalCount == 0 {
                EmptyStateView(
                    title: "No words yet",
                    systemImage: "character.book.closed",
                    message: "Add your first word. It works offline.",
                    actionTitle: "Add Word",
                    action: { addKind = .word; isAdding = true }
                )
            } else if viewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Text("┌─────────┐\n│  · · ·  │\n└─────────┘")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(AppColor.faint)
                    Text("Nothing found").font(.system(size: 17, weight: .medium)).foregroundStyle(AppColor.ink)
                    if !viewModel.query.isEmpty {
                        Button { addKind = .word; isAdding = true } label: { Text("Add “\(viewModel.query)”") }
                            .buttonStyle(GlassButtonStyle(height: 44))
                            .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.results) { word in
                            Button { openedWord = word } label: {
                                WordRow(word: word, status: viewModel.status(of: word))
                                    .matchedTransitionSource(id: word.id, in: zoom)
                            }
                            .buttonStyle(PressScaleStyle())
                            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(AppColor.hairline)
                            .onAppear { viewModel.loadMoreIfNeeded(after: word) }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { viewModel.markKnown(word) } label: { Label("I know", systemImage: "checkmark") }
                                    .tint(AppColor.accent)
                            }
                            .swipeActions(edge: .trailing) {
                                Button { viewModel.suspend(word) } label: { Label("Suspend", systemImage: "pause") }
                                    .tint(AppColor.smoke)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .padding(.top, 8)
                    .onChange(of: container.router.reselectCount) { _, _ in
                        guard container.router.reselectedTab == .words, let first = viewModel.results.first?.id else { return }
                        withAnimation(.smooth(duration: 0.35)) {
                            proxy.scrollTo(first, anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

/// Два раздела словаря (ABOUT.md, раздел 9.1).
enum WordsSection: String, CaseIterable, Identifiable {
    case words
    case idioms

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .words: "Words"
        case .idioms: "Idioms"
        }
    }
}

private struct WordRow: View {
    let word: Word
    let status: LearningStatus

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(word.lemma).font(.system(size: 17, weight: .medium)).foregroundStyle(AppColor.ink)
                if !word.translation.isEmpty {
                    Text(word.translation).font(.system(size: 13)).foregroundStyle(AppColor.ash).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 7) {
                    Text(status.rawValue).font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColor.smoke)
                    StatusDot(status: status)
                }
                if status == .new {
                    EmptyView()
                } else if status == .known {
                    Text("✓").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.accent)
                } else if status == .suspended {
                    Text("‖").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                } else {
                    MemoryBar(level: status.strength)
                }
            }
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
