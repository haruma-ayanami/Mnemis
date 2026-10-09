import Foundation
import Observation

/// Раздел «Idioms»: личные идиомы, поиск и удаление (ABOUT.md, раздел 9.1).
@Observable
@MainActor
final class PhrasesViewModel {
    var query = "" { didSet { reload() } }

    private(set) var phrases: [Phrase] = []
    private(set) var totalCount = 0
    private(set) var state: ScreenState = .loading

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func load() {
        do {
            totalCount = try container.phrases.count()
            reload()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func delete(_ phrase: Phrase) {
        do {
            try container.phraseEditor.delete(id: phrase.id)
            load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func toggleKnown(_ phrase: Phrase) {
        do {
            _ = try container.phraseEditor.setKnown(!phrase.isKnown, for: phrase)
            load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func reload() {
        do {
            phrases = try container.phrases.search(query)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
