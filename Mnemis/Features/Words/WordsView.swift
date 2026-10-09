import SwiftUI

/// Личный словарь: поиск, фильтры по статусам, список, добавление (ABOUT.md, раздел 15).
struct WordsView: View {
    @State private var viewModel: WordsViewModel
    @State private var isAdding = false
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: WordsViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    header
                    searchField.padding(.top, 18)
                    chips.padding(.top, 14)
                    list
                }
                .padding(.horizontal, 20)
            }
            .mnemisNavigationBarHidden()
            .sheet(isPresented: $isAdding, onDismiss: { viewModel.load() }) {
                AddWordView(viewModel: viewModel, initialLemma: viewModel.query)
            }
            .onAppear { viewModel.load() }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Words").font(.mnemisTitle).tracking(-0.8).foregroundStyle(AppColor.ink)
                Text("\(viewModel.words.count.formatted()) in your vocabulary")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
            }
            Spacer()
            RoundGlassButton(systemImage: "plus", label: "Add word") { isAdding = true }
        }
        .padding(.top, 8)
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
                .buttonStyle(.plain)
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var list: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message)
        case .loaded:
            if viewModel.words.isEmpty {
                EmptyStateView(
                    title: "No words yet",
                    systemImage: "character.book.closed",
                    message: "Add your first word. It works offline.",
                    actionTitle: "Add Word",
                    action: { isAdding = true }
                )
            } else if viewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Text("┌─────────┐\n│  · · ·  │\n└─────────┘")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(AppColor.faint)
                    Text("Nothing found").font(.system(size: 17, weight: .medium)).foregroundStyle(AppColor.ink)
                    if !viewModel.query.isEmpty {
                        Button { isAdding = true } label: { Text("Add “\(viewModel.query)”") }
                            .buttonStyle(GlassButtonStyle(height: 44))
                            .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.results) { word in
                            NavigationLink {
                                WordDetailsView(word: word, container: container, onChange: { viewModel.load() })
                            } label: {
                                WordRow(word: word, status: viewModel.status(of: word))
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(AppColor.hairline)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 8)
            }
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
