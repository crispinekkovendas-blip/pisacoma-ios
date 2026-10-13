import Combine
import SwiftUI

/// The navigation stack of routes. `go` pushes (single top), `reload` replaces the top with a
/// fresh copy (a new view and model, for «Reintentar»), `continueFirstRun` leaves the bare chooser.
@MainActor
final class Router: ObservableObject {
    @Published var path: [Route] = []
    /// The destination the first open continues to after /descargas (a deep link, else the home).
    var after: Route? = nil
    /// The root of the stack: the home, or /descargas on the first open.
    @Published var root: Route

    /// Bumped by `reload` so the same route gets a fresh view identity.
    @Published private(set) var generation = 0

    init(root: Route = .home, after: Route? = nil) {
        self.root = root
        self.after = after
    }

    var current: Route { path.last ?? root }

    func go(_ route: Route) {
        if current == route { return }
        if route == root && path.isEmpty { return }
        if route == root { path.removeAll(); return }
        path.append(route)
    }

    func back() { if !path.isEmpty { path.removeLast() } }

    func reload() { generation += 1 }

    /// After the first open's choice: the stack becomes the home (and the deep link above it).
    func continueFirstRun() {
        root = .home
        path = after.flatMap { $0 == .home ? nil : $0 }.map { [$0] } ?? []
        after = nil
    }
}
