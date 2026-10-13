import XCTest
@testable import Pisacoma

/// Port of the site's videos/data.ts helpers: CHANNELS, CATS regexes, tagVideo, fmtTime, thumbs.
final class VideoCatalogTests: XCTestCase {
    func testChannelsAreTheSitesFour() {
        XCTAssertEqual(VideoCatalog.channels.map(\.key), ["bullon", "flores", "sumtv", "lecciones"])
        XCTAssertEqual(VideoCatalog.channels[0].id, "UCzY9YOmZquSEERTbl_u-MSQ")
        XCTAssertEqual(VideoCatalog.channels[0].label, "Pr. Alejandro Bullón")
        XCTAssertEqual(VideoCatalog.channels[0].shortLabel, "Bullón")
    }

    func testCategoriesInTheSitesOrder() {
        XCTAssertEqual(VideoCatalog.cats.map(\.key), ["sermones", "escuela_sabatica", "musica", "profecia", "salud_familia", "en_vivo", "juveniles", "ninos", "egw", "pisacoma"])
        XCTAssertEqual(VideoCatalog.cats[0].label, "Sermones · Predicación")
    }

    func testTagVideoUsesTitleRegexesManualTagsAndChannel() {
        let v = VideoEntry(videoId: "x", title: "Sermón: la gracia de Daniel", tags: ["destacado"], channel: "bullon")
        XCTAssertEqual(VideoCatalog.tagVideo(v).tags, ["sermones", "profecia", "destacado", "channel:bullon"])
    }

    func testTagVideoIsCaseInsensitiveAndAccentTolerant() {
        XCTAssertTrue(VideoCatalog.tagVideo(VideoEntry(videoId: "x", title: "LECCION 4 — Escuela Sabatica")).tags.contains("escuela_sabatica"))
        XCTAssertTrue(VideoCatalog.tagVideo(VideoEntry(videoId: "x", title: "Culto JA de jóvenes")).tags.contains("juveniles"))
        XCTAssertTrue(VideoCatalog.tagVideo(VideoEntry(videoId: "x", title: "Altiplano aimara")).tags.contains("pisacoma"))
    }

    func testFmtTime() {
        XCTAssertEqual(VideoCatalog.fmtTime(0), "0:00")
        XCTAssertEqual(VideoCatalog.fmtTime(75), "1:15")
        XCTAssertEqual(VideoCatalog.fmtTime(725.4), "12:05")
        XCTAssertEqual(VideoCatalog.fmtTime(.nan), "0:00")
    }

    func testThumbnailUrl() {
        XCTAssertEqual(VideoCatalog.thumb("abc", "hqdefault"), "https://i.ytimg.com/vi/abc/hqdefault.jpg")
        XCTAssertEqual(VideoCatalog.thumbSizes, ["maxresdefault", "hqdefault", "sddefault", "mqdefault", "default"])
    }

    func testRelativeTimeInSpanish() {
        let now: Int64 = 1_791_000_000_000
        XCTAssertEqual(VideoCatalog.relTimeEs(now - 1 * 86_400_000, now: now), "ayer")
        XCTAssertEqual(VideoCatalog.relTimeEs(now - 3 * 86_400_000, now: now), "hace 3 días")
        XCTAssertEqual(VideoCatalog.relTimeEs(now - 3 * 3_600_000, now: now), "hace 3 horas")
        XCTAssertEqual(VideoCatalog.relTimeEs(now - 5 * 60_000, now: now), "hace 5 minutos")
        XCTAssertEqual(VideoCatalog.relTimeEs(now - 61 * 86_400_000, now: now), "hace 2 meses")
        XCTAssertEqual(VideoCatalog.relTimeEs(now - 400 * 86_400_000, now: now), "el año pasado")
        XCTAssertEqual(VideoCatalog.relTimeEs(nil, now: now), "")
        XCTAssertEqual(VideoCatalog.relTimeEsIso("2026-10-01T10:00:00Z", now: 1_791_000_000_000), VideoCatalog.relTimeEs(1_790_848_800_000, now: 1_791_000_000_000))
    }

    func testFeedJsonParses() {
        let list = VideoCatalog.parseFeed("{\"videos\":[{\"videoId\":\"a1\",\"title\":\"Sermón uno\",\"published\":\"2026-10-01T10:00:00Z\",\"channel\":\"flores\"},{\"videoId\":\"b2\",\"title\":\"Lección 2\",\"channel\":\"lecciones\",\"hero\":true}]}")
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].videoId, "a1")
        XCTAssertEqual(list[1].hero, true)
        XCTAssertTrue(VideoCatalog.parseFeed("not json").isEmpty)
    }
}
