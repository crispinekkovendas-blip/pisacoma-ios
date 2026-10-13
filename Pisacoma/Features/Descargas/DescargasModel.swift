import Combine
import Foundation

struct DescargasUi: Equatable {
    struct Option: Equatable, Identifiable {
        let mode: ContentMode
        let desc: String
        let size: String
        var id: String { mode.value }
    }
    /// The chosen mode; nil on the first open.
    let current: ContentMode?
    /// The four options in the spec's order.
    let options: [Option]
    let download: DownloadState
    /// «Guardado en este teléfono · 12 MB», or empty when nothing is stored.
    let storedText: String
    let canContinue: Bool
    /// Files the current mode wants that are not on disk (→ «Completar»).
    let missingCount: Int
}

/// The /descargas screen state over the store, the downloader and the user state (Android DescargasViewModel).
@MainActor
final class DescargasModel: ObservableObject {
    @Published private(set) var state: DescargasUi
    private let store: ContentStore
    private let downloader: ContentDownloader
    private let userState: UserState
    private var bag: Set<AnyCancellable> = []

    init(store: ContentStore, downloader: ContentDownloader, userState: UserState) {
        self.store = store
        self.downloader = downloader
        self.userState = userState
        state = Self.build(store: store, downloader: downloader, userState: userState)
        downloader.$state.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }.store(in: &bag)
    }

    private static func current(_ userState: UserState) -> ContentMode? { ContentMode.of(userState.string(UserState.Keys.contentMode)) }

    private static func build(store: ContentStore, downloader: ContentDownloader, userState: UserState) -> DescargasUi {
        let current = current(userState)
        let m = store.manifest
        let stored = store.storedBytes()
        return DescargasUi(
            current: current,
            options: [
                .init(mode: .todo, desc: "Himnarios, Biblia, lecciones, quiz, búsqueda y los 25 libros de EGW.", size: formatMb(m.totalBytes)),
                .init(mode: .esencial, desc: "Himnario, Biblia, lecciones, quiz y búsqueda. Los libros de EGW se guardan cuando los abras.", size: formatMb(m.bytesOf(Packs.essential))),
                .init(mode: .uso, desc: "No descarga nada ahora; cada himno, capítulo o libro que abras se guarda para la próxima vez.", size: ""),
                .init(mode: .enLinea, desc: "Nada se guarda en el teléfono; hace falta señal para leer.", size: ""),
            ],
            download: downloader.state,
            storedText: stored > 0 ? "Guardado en este teléfono · \(formatMb(stored))" : "",
            canContinue: current != nil,
            missingCount: current?.downloads == true ? downloader.missingFor(current!).count : 0
        )
    }

    func refresh() { state = Self.build(store: store, downloader: downloader, userState: userState) }

    /// Stores the choice; the two download modes start at once and stay «pendiente» until complete.
    func choose(_ mode: ContentMode) {
        userState.set(UserState.Keys.contentMode, mode.value)
        if mode.downloads {
            userState.set(UserState.Keys.contentPending, true)
            downloader.start(mode)
        } else {
            userState.set(UserState.Keys.contentPending, false)
        }
        refresh()
    }

    /// «Reintentar» / «Completar»: download what the current mode still lacks.
    func complete() {
        guard let mode = Self.current(userState) else { return }
        if mode.downloads {
            userState.set(UserState.Keys.contentPending, true)
            downloader.start(mode)
        }
        refresh()
    }

    /// «Borrar lo descargado»: empties the store, keeps the mode.
    func clear() {
        store.clear()
        if Self.current(userState)?.downloads == true { userState.set(UserState.Keys.contentPending, true) }
        refresh()
    }
}
