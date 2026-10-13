import Foundation

/**
 Port of the site's src/utils/zmanim.ts: NOAA sunset/sunrise for Pisacoma, the week's Sabbath
 (Friday sunset → Saturday sunset), Peru civil dates and the labels the home shows.
 Instants are epoch milliseconds (UTC); civil days are 00:00 UTC of the local date.
 */
enum Zmanim {
    struct Place { let lat: Double; let lng: Double; let tzOffsetHours: Int }
    static let pisacoma = Place(lat: -16.908, lng: -69.365, tzOffsetHours: -5)

    private static let deg2rad = Double.pi / 180
    private static let rad2deg = 180 / Double.pi
    private static let day: Int64 = 86_400_000

    private static func julianCenturies(_ ms: Int64) -> Double { (Double(ms) / 86400000.0 + 2440587.5 - 2451545.0) / 36525.0 }
    private static func meanLongitudeSun(_ t: Double) -> Double { (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360) }
    private static func meanAnomalySun(_ t: Double) -> Double { 357.52911 + t * (35999.05029 - 0.0001537 * t) }
    private static func equationOfCenter(_ t: Double) -> Double {
        let m = meanAnomalySun(t) * deg2rad
        return sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t)) + sin(2 * m) * (0.019993 - 0.000101 * t) + sin(3 * m) * 0.000289
    }
    private static func sunApparentLongitude(_ t: Double) -> Double {
        let omega = (125.04 - 1934.136 * t) * deg2rad
        return meanLongitudeSun(t) + equationOfCenter(t) - 0.00569 - 0.00478 * sin(omega)
    }
    private static func obliquityCorrection(_ t: Double) -> Double {
        let e0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let omega = (125.04 - 1934.136 * t) * deg2rad
        return e0 + 0.00256 * cos(omega)
    }
    private static func sunDeclination(_ t: Double) -> Double {
        let e = obliquityCorrection(t) * deg2rad
        let lambda = sunApparentLongitude(t) * deg2rad
        return asin(sin(e) * sin(lambda)) * rad2deg
    }
    private static func equationOfTime(_ t: Double) -> Double {
        let e = obliquityCorrection(t) * deg2rad
        let l0 = meanLongitudeSun(t) * deg2rad
        let m = meanAnomalySun(t) * deg2rad
        let ec = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let y = tan(e / 2) * tan(e / 2)
        let eot = y * sin(2 * l0) - 2 * ec * sin(m) + 4 * ec * y * sin(m) * cos(2 * l0) - 0.5 * y * y * sin(4 * l0) - 1.25 * ec * ec * sin(2 * m)
        return eot * 4 * rad2deg
    }

    /// Sunset (or sunrise) as a UTC instant for the civil date `dayUtcMidnight`, or nil at the poles.
    private static func sunEvent(_ dayUtcMidnight: Int64, _ lat: Double, _ lng: Double, rising: Bool) -> Int64? {
        let t = julianCenturies(dayUtcMidnight)
        let eqTime = equationOfTime(t)
        let decl = sunDeclination(t) * deg2rad
        let latR = lat * deg2rad
        let zenR = 90.833 * deg2rad
        let cosHA = (cos(zenR) - sin(latR) * sin(decl)) / (cos(latR) * cos(decl))
        if cosHA < -1 || cosHA > 1 { return nil }
        let haDeg = acos(cosHA) * rad2deg
        let solarNoon = 720 - 4 * lng - eqTime
        let minutesUtc = solarNoon + 4 * (rising ? -haDeg : haDeg)
        return dayUtcMidnight + Int64(minutesUtc * 60000)
    }

    static func sunsetUtc(_ dayUtcMidnight: Int64, lat: Double = pisacoma.lat, lng: Double = pisacoma.lng) -> Int64? { sunEvent(dayUtcMidnight, lat, lng, rising: false) }
    static func sunriseUtc(_ dayUtcMidnight: Int64, lat: Double = pisacoma.lat, lng: Double = pisacoma.lng) -> Int64? { sunEvent(dayUtcMidnight, lat, lng, rising: true) }

    struct SabbathTimes: Equatable { let start: Int64?; let end: Int64?; let friday: Int64; let saturday: Int64; let isSabbath: Bool }

    /// The Sabbath of the current week in Pisacoma local time; after Saturday's sunset, the next one.
    static func sabbathTimes(_ nowUtc: Int64, tzOffset: Int = pisacoma.tzOffsetHours) -> SabbathTimes {
        let local = ymd(nowUtc + Int64(tzOffset) * 3_600_000)
        let wd = weekday(nowUtc + Int64(tzOffset) * 3_600_000) // 0 Sun … 6 Sat
        var toFriday = wd == 6 ? -1 : (5 - wd + 7) % 7
        var end = sunsetUtc(utcMidnight(local.y, local.m, local.d + toFriday + 1))
        if let e = end, nowUtc >= e {
            toFriday += 7
            end = sunsetUtc(utcMidnight(local.y, local.m, local.d + toFriday + 1))
        }
        let friday = utcMidnight(local.y, local.m, local.d + toFriday)
        let saturday = utcMidnight(local.y, local.m, local.d + toFriday + 1)
        let start = sunsetUtc(friday)
        let isSabbath: Bool
        if let s = start, let e = end { isSabbath = nowUtc >= s && nowUtc < e } else { isSabbath = false }
        return SabbathTimes(start: start, end: end, friday: friday, saturday: saturday, isSabbath: isSabbath)
    }

    /// 00:00 UTC of the civil date in Pisacoma.
    static func localCivilDate(_ nowUtc: Int64, tzOffset: Int = pisacoma.tzOffsetHours) -> Int64 {
        let l = ymd(nowUtc + Int64(tzOffset) * 3_600_000)
        return utcMidnight(l.y, l.m, l.d)
    }

    /// "27/06/2026" → 00:00 UTC of that date.
    static func parseDMY(_ s: String) -> Int64 {
        let p = s.trimmingCharacters(in: .whitespaces).split(separator: "/").map { Int($0) ?? 0 }
        guard p.count == 3 else { return 0 }
        return utcMidnight(p[2], p[1] - 1, p[0])
    }

    enum QuarterState { case upcoming, active, ended }
    struct QuarterDates { let startDate: String; let endDate: String }
    struct QuarterStatus: Equatable { let state: QuarterState; let nextStart: Int64 }

    /// Where today (Pisacoma) falls relative to a quarterly's "dd/mm/yyyy" dates.
    static func quarterStatus(_ q: QuarterDates, _ nowUtc: Int64) -> QuarterStatus {
        let today = localCivilDate(nowUtc)
        let start = parseDMY(q.startDate)
        let end = parseDMY(q.endDate)
        let state: QuarterState = today < start ? .upcoming : (today > end ? .ended : .active)
        return QuarterStatus(state: state, nextStart: end + day)
    }

    /// Index of the lesson whose start_date is the latest one on or before today (Pisacoma).
    static func currentLessonIndex(_ startDates: [String], _ nowUtc: Int64) -> Int {
        let today = localCivilDate(nowUtc)
        for i in startDates.indices.reversed() where today >= parseDMY(startDates[i]) { return i }
        return 0
    }

    struct Clock12: Equatable { let time: String; let suffix: String }

    /// "5:37" / "PM" in Peru time, or "--:--" for a nil instant (site clock12).
    static func clock12(_ utc: Int64?, tzOffset: Int = pisacoma.tzOffsetHours) -> Clock12 {
        guard let utc else { return Clock12(time: "--:--", suffix: "") }
        let local = utc + Int64(tzOffset) * 3_600_000
        let secondsOfDay = Int(((local % day) + day) % day / 1000)
        let h24 = secondsOfDay / 3600
        let minute = (secondsOfDay % 3600) / 60
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return Clock12(time: "\(h12):" + String(format: "%02d", minute), suffix: h24 < 12 ? "AM" : "PM")
    }

    private static let weekdays = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    // es-PE short months (CLDR): note "set" for septiembre
    private static let monthsShort = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "set", "oct", "nov", "dic"]
    private static let monthsLong = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    /// "Viernes 18 set" for a 00:00 UTC civil date (site dayLabel, es-PE).
    static func dayLabel(_ dayUtcMidnight: Int64) -> String {
        let l = ymd(dayUtcMidnight)
        let wd = weekdays[weekday(dayUtcMidnight)]
        return "\(wd.prefix(1).uppercased() + wd.dropFirst()) \(l.d) \(monthsShort[l.m])"
    }

    /// "sábado 26 de septiembre" for a 00:00 UTC civil date (site longDayLabel).
    static func longDayLabel(_ dayUtcMidnight: Int64) -> String {
        let l = ymd(dayUtcMidnight)
        return "\(weekdays[weekday(dayUtcMidnight)]) \(l.d) de \(monthsLong[l.m])"
    }

    // ---- civil calendar in UTC (proleptic Gregorian, via Foundation) ----
    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private static func ymd(_ ms: Int64) -> (y: Int, m: Int, d: Int) {
        let comps = utcCalendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(ms) / 1000))
        return (comps.year!, comps.month! - 1, comps.day!)
    }

    /// 0 = Sunday … 6 = Saturday.
    private static func weekday(_ ms: Int64) -> Int {
        utcCalendar.component(.weekday, from: Date(timeIntervalSince1970: Double(ms) / 1000)) - 1
    }

    /// 00:00 UTC of year / month (0-based) / day, where `d` may overflow the month (as Calendar.add on Android).
    static func utcMidnight(_ y: Int, _ m0: Int, _ d: Int) -> Int64 {
        var comps = DateComponents()
        comps.year = y; comps.month = m0 + 1; comps.day = 1; comps.hour = 0; comps.minute = 0; comps.second = 0
        let first = utcCalendar.date(from: comps)!
        let date = utcCalendar.date(byAdding: .day, value: d - 1, to: first)!
        return Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
