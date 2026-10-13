import Combine
import Foundation

/// Photo credits shown in the night scene (site src/data/home-photos.ts).
struct HomePhoto: Codable, Equatable, Identifiable {
    let section: String
    let title: String
    let author: String
    let license: String
    let licenseUrl: String
    let source: String
    var id: String { section }
}

private struct AnunciosFile: Codable {
    var csvUrl: String? = ""
    var items: [Anuncio]? = []
}

struct HomeUi: Equatable {
    var quarterTitle = ""
    var weeksTotal = 13
    var escWeek = 1
    var escEnded = false
    var sabbath: Zmanim.SabbathTimes? = nil
    var schedule: [ScheduleItem] = []
    var anuncios: [AnuncioView] = []
    var photos: [HomePhoto] = []
    var paused = false
}

/// The live bits the site renders over the motion: lesson of the week, Sabbath sunset, schedule, announcements, the pause flag.
@MainActor
final class HomeModel: ObservableObject {
    @Published private(set) var state: HomeUi
    private let app: AppModel

    init(app: AppModel) {
        self.app = app
        state = HomeUi(paused: app.userState.bool(UserState.Keys.homePaused))
        Task { await load() }
    }

    private func load() async {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        do {
            let q = try await app.quarterly.quarterly()
            let c = try await app.church.church()
            let photos = (try? AppJson.decode([HomePhoto].self, try await app.content.read("data/home-photos.json"))) ?? []
            state.quarterTitle = q.title
            state.weeksTotal = q.lessons.count
            state.escWeek = Zmanim.currentLessonIndex(q.lessons.map(\.startDate), now) + 1
            state.escEnded = Zmanim.quarterStatus(Zmanim.QuarterDates(startDate: q.startDate, endDate: q.endDate), now).state == .ended
            state.sabbath = Zmanim.sabbathTimes(now)
            state.schedule = c.schedule
            state.photos = photos
        } catch let e as ContentMissing {
            ContentErrors.report(e, app: app)
        } catch {
            // the indices are bundled; nothing else to do
        }
        let file = (try? AppJson.decode(AnunciosFile.self, try await app.content.read("data/anuncios.json"))) ?? AnunciosFile()
        state.anuncios = await Anuncios.load(local: file.items ?? [], csvUrl: file.csvUrl ?? "", nowUtc: now)
    }

    func togglePause() {
        let next = !state.paused
        app.userState.set(UserState.Keys.homePaused, next)
        state.paused = next
    }
}

/// A ContentMissing caught by a screen model becomes the one notice the chrome shows.
enum ContentErrors {
    @MainActor static func report(_ e: ContentMissing, app: AppModel) { app.content.missing = e.path }
}
