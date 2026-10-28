// Gebetszeiten: Menüleisten-App mit den IGMG-Gebetszeiten für den aktuellen Standort
// (nächste IGMG-Stadt) oder eine gewählte Stadt, Countdown bis zum nächsten Vakit und Kerahat-Zeiten.
import AppKit
import SwiftUI
import ServiceManagement
import CoreLocation
import CryptoKit

// MARK: - Grundlagen

let defaultCityID = "20083" // Hamburg
/// Kalender in der Zeitzone der gewählten Stadt (IGMG liefert Ortszeit der Stadt)
var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Berlin")!; return c }()
let apiURL = URL(string: "https://www.igmg.org/wp-content/themes/igmg/include/gebetskalender_ajax_api.php")!

enum Vakit: Int, CaseIterable {
    case imsak, gunes, ogle, ikindi, aksam, yatsi
    var tr: String { ["İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"][rawValue] }
    var ar: String { ["Fajr", "Shuruq", "Dhuhr", "Asr", "Maghrib", "Isha"][rawValue] }
    var arab: String { ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"][rawValue] }
    var de: String { ["Morgen", "Sonnenaufgang", "Mittag", "Nachmittag", "Abend", "Nacht"][rawValue] }
    var en: String { ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"][rawValue] }

    /// Name in der gewählten Schreibweise
    var name: String {
        switch nameStyle {
        case .tr: return tr
        case .ar: return ar
        case .arab: return arab
        case .de: return de
        case .en: return en
        }
    }
    /// Zweitname in der Oberflächensprache, leer wenn er dem Namen entspricht
    var hint: String {
        let local: String
        switch appLang {
        case .de: local = de
        case .tr: local = tr
        case .en: local = en
        case .ar: local = arab
        }
        return local == name ? "" : local
    }
}

/// Wie die Gebete heißen: türkisch (İkindi, Akşam), arabisch (Asr, Maghrib) oder deutsch
enum NameStyle: String, CaseIterable {
    case tr, ar, arab, de, en
    var label: String {
        L(["tr": "Türkisch (Akşam)", "ar": "Arabisch, Umschrift (Maghrib)", "arab": "Arabisch, Schrift (المغرب)",
           "de": "Deutsch (Abend)", "en": "Englisch (Sunset)"][rawValue]!)
    }
    /// Wort für die Zeiten ohne Gebet
    var kerahat: String {
        switch self {
        case .ar, .en: return "Makruh"
        case .arab: return "مكروه"
        default: return "Kerahat"
        }
    }
}

/// Ohne eigene Wahl passend zur Sprache: Arabisch in Schrift, Englisch in Umschrift, sonst türkisch
var nameStyle = NameStyle(rawValue: UserDefaults.standard.string(forKey: "names") ?? "")
    ?? [AppLang.ar: NameStyle.arab, .en: .ar][appLang] ?? .tr

struct Event { let vakit: Vakit; let date: Date }

struct Kerahat {
    let label: String
    let start: Date
    let end: Date
    func contains(_ d: Date) -> Bool { d >= start && d < end }
}

/// IGMG-Stadt, Koordinaten + Zeitzone aus GeoNames (siehe build_cities.py)
struct City: Equatable {
    let id: String
    let label: String // z. B. "Berlin (DE)"
    let lat: Double?
    let lon: Double?
    let tz: String?

    var name: String { label.replacingOccurrences(of: #"\s*\([A-Z]{2,3}\)$"#, with: "", options: .regularExpression) }
    var timeZone: TimeZone { tz.flatMap { TimeZone(identifier: $0) } ?? .current }
    var pageURL: URL {
        let stadt = label.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.igmg.org/gebetskalender?stadt=\(stadt)&id=\(id)")!
    }
}

enum Cities {
    static let all: [City] = {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return [] }
        return rows.compactMap { r in
            guard r.count == 5, let id = r[0] as? String, let label = r[1] as? String else { return nil }
            return City(id: id, label: label, lat: r[2] as? Double, lon: r[3] as? Double, tz: r[4] as? String)
        }
    }()

    static func find(_ id: String) -> City? { all.first { $0.id == id } }

    static func nearest(to loc: CLLocation) -> (city: City, km: Double)? {
        var best: (City, Double)?
        for c in all {
            guard let lat = c.lat, let lon = c.lon else { continue }
            let d = loc.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000
            if best == nil || d < best!.1 { best = (c, d) }
        }
        return best.map { (city: $0.0, km: $0.1) }
    }

    /// Suche ohne Rücksicht auf Akzente/Groß-Klein; Treffer am Wortanfang und deutsche Städte zuerst
    static func search(_ q: String, limit: Int = 8) -> [City] {
        let n = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return [] }
        let hits = all.compactMap { c -> (City, Int)? in
            let l = c.label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            guard let r = l.range(of: n) else { return nil }
            var score = r.lowerBound == l.startIndex ? 0 : 2
            if !c.label.hasSuffix("(DE)") { score += 1 }
            return (c, score)
        }
        return hits.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.label < $1.0.label }.prefix(limit).map(\.0)
    }
}

func dayKey(_ d: Date) -> String {
    let c = cal.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

func hm(_ d: Date) -> String {
    let c = cal.dateComponents([.hour, .minute], from: d)
    return String(format: "%02d:%02d", c.hour!, c.minute!)
}

func countdown(_ secs: TimeInterval, seconds: Bool = true) -> String {
    let s = max(0, Int(secs.rounded(.up)))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    if !seconds {
        let mm = (s + 59) / 60
        return mm >= 60 ? String(format: "%d:%02d ", mm / 60, mm % 60) + L("h") : "\(mm) " + L("min")
    }
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

// MARK: - Daten (IGMG-Abruf + Cache)

enum IGMG {
    static func fetchMonth(city: City, year: Int, month: Int) async throws -> [String: [String]] {
        var req = URLRequest(url: apiURL, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue(city.pageURL.absoluteString, forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0 (Macintosh) Gebetszeiten", forHTTPHeaderField: "User-Agent")
        req.httpBody = "show_ajax_variable=\(city.id)&show_month=\(month)&show_year=\(year)&lang=de".data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        let days = parse(String(decoding: data, as: UTF8.self))
        if days.isEmpty { throw URLError(.cannotParseResponse) }
        return days
    }

    static func parse(_ html: String) -> [String: [String]] {
        let row = try! NSRegularExpression(pattern: #"class="tarih">(\d{2})\.(\d{2})\.(\d{4})</span>((?:\s*<span class="\w+_time">\d{2}:\d{2}</span>){6})"#)
        let time = try! NSRegularExpression(pattern: #"\d{2}:\d{2}"#)
        let ns = html as NSString
        var out: [String: [String]] = [:]
        for m in row.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let d = ns.substring(with: m.range(at: 1)), mo = ns.substring(with: m.range(at: 2)), y = ns.substring(with: m.range(at: 3))
            let block = ns.substring(with: m.range(at: 4)) as NSString
            let times = time.matches(in: block as String, range: NSRange(location: 0, length: block.length)).map { block.substring(with: $0.range) }
            if times.count == 6 { out["\(y)-\(mo)-\(d)"] = times }
        }
        return out
    }
}

@MainActor
final class Store: ObservableObject {
    @Published var days: [String: [String]] = [:]
    @Published var lastFetch: Date?
    @Published var error: String?
    @Published var loading = false
    @Published var now = Date()
    @Published private(set) var city: City
    /// Stadt automatisch aus dem Standort bestimmen
    @Published var autoLocation: Bool { didSet { UserDefaults.standard.set(autoLocation, forKey: "autoLocation") } }
    @Published var locationNote: String?
    /// Platz unter der Menüleiste, damit das Fenster nie länger als der Bildschirm wird
    @Published var maxHeight: CGFloat = 2000
    @Published var names: NameStyle = nameStyle {
        didSet { nameStyle = names; UserDefaults.standard.set(names.rawValue, forKey: "names") }
    }
    @Published var lang: AppLang = appLang {
        didSet { appLang = lang; UserDefaults.standard.set(lang.rawValue, forKey: "lang"); locationNote = nil }
    }

    // Kerahat-Fenster in Minuten (Standard nach Diyanet/IGMG-Praxis: ca. 45 Minuten)
    @Published var kSunrise: Int { didSet { UserDefaults.standard.set(kSunrise, forKey: "kSunrise") } }
    @Published var kNoon: Int { didSet { UserDefaults.standard.set(kNoon, forKey: "kNoon") } }
    @Published var kSunset: Int { didSet { UserDefaults.standard.set(kSunset, forKey: "kSunset") } }
    @Published var showSeconds: Bool { didSet { UserDefaults.standard.set(showSeconds, forKey: "showSeconds") } }

    private static let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Gebetszeiten")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private var cacheURL: URL { Self.cacheDir.appendingPathComponent("stadt-\(city.id).json") }
    private var lastFetchKey: String { "lastFetch-\(city.id)" }

    init() {
        let ud = UserDefaults.standard
        ud.register(defaults: ["kSunrise": 45, "kNoon": 45, "kSunset": 45, "showSeconds": true, "autoLocation": true, "cityID": defaultCityID])
        kSunrise = ud.integer(forKey: "kSunrise")
        kNoon = ud.integer(forKey: "kNoon")
        kSunset = ud.integer(forKey: "kSunset")
        showSeconds = ud.bool(forKey: "showSeconds")
        autoLocation = ud.bool(forKey: "autoLocation")
        city = Cities.find(ud.string(forKey: "cityID") ?? defaultCityID)
            ?? City(id: defaultCityID, label: "Hamburg (DE)", lat: 53.55, lon: 9.99, tz: "Europe/Berlin")
        loadCity()
    }

    private func loadCity() {
        cal.timeZone = city.timeZone
        days = (try? Data(contentsOf: cacheURL)).flatMap { try? JSONDecoder().decode([String: [String]].self, from: $0) } ?? [:]
        lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date
        error = nil
    }

    func setCity(_ c: City) {
        guard c.id != city.id else { return }
        city = c
        UserDefaults.standard.set(c.id, forKey: "cityID")
        loadCity()
        loading = false
        refresh()
    }

    /// Lädt neu, wenn heute oder morgen fehlt oder der letzte Abruf nicht von heute ist.
    func refreshIfNeeded() {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let stale = lastFetch.map { !cal.isDate($0, inSameDayAs: now) } ?? true
        if days[dayKey(now)] == nil || days[dayKey(tomorrow)] == nil || stale { refresh() }
    }

    func refresh() {
        guard !loading else { return }
        loading = true
        let thisMonth = cal.dateComponents([.year, .month], from: now)
        let next = cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: 1, to: now)!)
        let target = city
        Task {
            do {
                var merged = days
                for c in [thisMonth, next] {
                    merged.merge(try await IGMG.fetchMonth(city: target, year: c.year!, month: c.month!)) { _, new in new }
                }
                guard target == city else { return } // Stadt wurde inzwischen gewechselt
                // Alte Tage (älter als 40 Tage) aus dem Cache werfen
                let cutoff = dayKey(cal.date(byAdding: .day, value: -40, to: now)!)
                merged = merged.filter { $0.key >= cutoff }
                days = merged
                lastFetch = Date()
                UserDefaults.standard.set(lastFetch, forKey: lastFetchKey)
                error = nil
                if let data = try? JSONEncoder().encode(merged) { try? data.write(to: cacheURL) }
            } catch {
                guard target == city else { return }
                self.error = days[dayKey(now)] == nil
                    ? L("IGMG nicht erreichbar, keine Zeiten für heute.")
                    : L("IGMG nicht erreichbar, zeige gespeicherte Zeiten.")
            }
            loading = false
        }
    }

    // MARK: Berechnung

    func events(on day: Date) -> [Event]? {
        guard let t = days[dayKey(day)] else { return nil }
        let base = cal.dateComponents([.year, .month, .day], from: day)
        return t.enumerated().compactMap { i, s in
            let p = s.split(separator: ":").compactMap { Int($0) }
            guard p.count == 2 else { return nil }
            var c = base; c.hour = p[0]; c.minute = p[1]; c.timeZone = cal.timeZone
            return cal.date(from: c).map { Event(vakit: Vakit(rawValue: i)!, date: $0) }
        }
    }

    func kerahat(on day: Date) -> [Kerahat] {
        guard let e = events(on: day), e.count == 6 else { return [] }
        let m = { (min: Int) in TimeInterval(min * 60) }
        return [
            Kerahat(label: L("nach Sonnenaufgang"), start: e[1].date, end: e[1].date + m(kSunrise)),
            Kerahat(label: L("vor %@ (Istiwa)", Vakit.ogle.name), start: e[2].date - m(kNoon), end: e[2].date),
            Kerahat(label: L("vor Sonnenuntergang"), start: e[4].date - m(kSunset), end: e[4].date),
        ]
    }

    var today: [Event] { events(on: now) ?? [] }

    var timeline: [Event] {
        let y = cal.date(byAdding: .day, value: -1, to: now)!, t = cal.date(byAdding: .day, value: 1, to: now)!
        return (events(on: y) ?? []) + today + (events(on: t) ?? [])
    }

    var current: Event? { timeline.last { $0.date <= now } }
    var next: Event? { timeline.first { $0.date > now } }

    var activeKerahat: Kerahat? { kerahat(on: now).first { $0.contains(now) } }

    var nextKerahat: Kerahat? {
        let t = cal.date(byAdding: .day, value: 1, to: now)!
        return (kerahat(on: now) + kerahat(on: t)).first { $0.start > now }
    }

    /// Worauf der Countdown läuft. Kommt vor dem nächsten Gebet eine Kerahat,
    /// läuft er bis zu deren Beginn (z. B. in der İkindi-Zeit bis zur Kerahat vor Akşam).
    struct Target { let title: String; let subtitle: String; let date: Date; let symbol: String; let kerahat: Bool; var untilKerahat = false }

    var target: Target? {
        if let k = activeKerahat {
            if let n = next, abs(n.date.timeIntervalSince(k.end)) < 61 {
                return Target(title: n.vakit.name, subtitle: L("%@, %@ um %@", nameStyle.kerahat, n.vakit.name, hm(n.date)), date: n.date, symbol: n.vakit.symbol, kerahat: true)
            }
            return Target(title: nameStyle.kerahat, subtitle: L("%@, endet um %@", k.label, hm(k.end)), date: k.end, symbol: "hourglass", kerahat: true)
        }
        guard let n = next else { return nil }
        if let k = nextKerahat, k.start < n.date {
            let ends = current.map { L("%@-Zeit endet um %@", $0.vakit.name, hm(k.start)) } ?? L("Endet um %@", hm(k.start))
            return Target(title: L("Bis %@", nameStyle.kerahat), subtitle: ends, date: k.start, symbol: "hourglass", kerahat: false, untilKerahat: true)
        }
        return Target(title: n.vakit.name, subtitle: n.vakit.hint.isEmpty ? L("um %@", hm(n.date)) : L("%@ um %@", n.vakit.hint, hm(n.date)), date: n.date, symbol: n.vakit.symbol, kerahat: false)
    }

    var menuTitle: String {
        guard let t = target else { return loading ? L("Lade…") : L("Keine Daten") }
        let label = t.untilKerahat ? L("%@ in", nameStyle.kerahat) : t.title
        return "\(label) \(countdown(t.date.timeIntervalSince(now), seconds: showSeconds))"
    }
}

// MARK: - Liquid Glass


/// Echtes Liquid Glass (NSGlassEffectView, macOS 26). Das SDK der Command Line Tools
/// kennt die Klasse noch nicht, darum Zugriff zur Laufzeit; ältere Systeme bekommen Milchglas.
func makeGlass(cornerRadius: CGFloat, tint: NSColor? = nil) -> NSView {
    if let cls = NSClassFromString("NSGlassEffectView") as? NSView.Type {
        let v = cls.init(frame: .zero)
        v.setValue(NSNumber(value: Double(cornerRadius)), forKey: "cornerRadius")
        if let tint { v.setValue(tint, forKey: "tintColor") }
        return v
    }
    let v = NSVisualEffectView()
    v.material = .popover
    v.state = .active
    v.wantsLayer = true
    v.layer?.cornerRadius = cornerRadius
    v.layer?.masksToBounds = true
    if let tint { v.layer?.backgroundColor = tint.withAlphaComponent(0.5).cgColor }
    return v
}

struct Glass: NSViewRepresentable {
    var cornerRadius: CGFloat
    var tint: NSColor? = nil
    func makeNSView(context: Context) -> NSView { makeGlass(cornerRadius: cornerRadius, tint: tint) }
    func updateNSView(_ v: NSView, context: Context) {
        if NSClassFromString("NSGlassEffectView").map({ v.isKind(of: $0) }) == true {
            v.setValue(tint, forKey: "tintColor")
        }
    }
}

// MARK: - Oberfläche (an das Kontrollzentrum von macOS 26 angelehnt)

extension Vakit {
    var symbol: String { ["moon.stars.fill", "sunrise.fill", "sun.max.fill", "sun.haze.fill", "sunset.fill", "moon.fill"][rawValue] }
}

/// Kachel wie im Kontrollzentrum: Glas, große Rundung, feine helle Kante
struct Tile<Content: View>: View {
    var radius: CGFloat = 26
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Glass(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
    }
}

/// Runder Symbolkreis: aktiv weiß mit blauem Symbol, sonst dezent
struct IconCircle: View {
    let symbol: String
    var active = false
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(active ? Color.accentColor : Color.primary)
            .frame(width: size, height: size)
            .background(Circle().fill(active ? Color.white : Color.primary.opacity(0.14)))
    }
}

/// Runder Glasknopf
struct CircleButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Glass(cornerRadius: 17))
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ContentView: View {
    @ObservedObject var s: Store
    @ObservedObject var u: Updater
    @State private var settingsOpen = false
    @State private var pickerOpen = false
    @State private var query = ""
    @State private var loginItem = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 10) {
            header
            // Passt alles auf den Bildschirm, wird nichts gescrollt; sonst scrollt der Mittelteil
            ViewThatFits(in: .vertical) {
                middle
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) { middle }
                        .onChange(of: settingsOpen) { open in
                            if open { withAnimation { proxy.scrollTo("settings", anchor: .bottom) } }
                        }
                        .onChange(of: pickerOpen) { open in
                            if open { withAnimation { proxy.scrollTo("picker", anchor: .top) } }
                        }
                }
            }
            footer
        }
        .padding(14)
        .frame(width: 340)
        .frame(maxHeight: s.maxHeight)
        .environment(\.layoutDirection, s.lang.rtl ? .rightToLeft : .leftToRight)
        .environment(\.locale, s.lang.locale)
    }

    private var middle: some View {
        VStack(spacing: 10) {
            if pickerOpen { cityPicker.id("picker").transition(.opacity) }
            heroTile
            prayerGrid
            kerahatTile
            if let err = s.error {
                Label(err, systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.secondary)
            }
            if let info = u.available { updateTile(info) }
            if settingsOpen { settingsTile.id("settings").transition(.opacity) }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Button {
                withAnimation(.spring(duration: 0.3)) { pickerOpen.toggle(); query = ""; if pickerOpen { settingsOpen = false } }
            } label: {
                HStack(spacing: 5) {
                    if s.autoLocation { Image(systemName: "location.fill").font(.system(size: 11)) }
                    Text(s.city.name).font(.headline)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("Stadt wählen"))
            Spacer()
            Text(s.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(s.lang.locale)))
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    private var cityPicker: some View {
        Tile(radius: 24, padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(get: { s.autoLocation }, set: { on in
                    s.autoLocation = on
                    if on { NotificationCenter.default.post(name: .requestLocation, object: nil) }
                })) {
                    Label(L("Automatisch per Standort"), systemImage: "location.fill").font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.switch).controlSize(.small)
                if let note = s.locationNote {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
                TextField(L("Stadt suchen, z. B. Berlin"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                ForEach(Cities.search(query), id: \.id) { c in
                    Button {
                        s.autoLocation = false
                        s.setCity(c)
                        withAnimation(.spring(duration: 0.3)) { pickerOpen = false; query = "" }
                    } label: {
                        HStack {
                            Text(c.label).font(.system(size: 12))
                            Spacer()
                            if c.id == s.city.id { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var heroTile: some View {
        Tile(radius: 28, padding: 14) {
            if let t = s.target {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        IconCircle(symbol: t.symbol, active: true, size: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.title).font(.system(size: 16, weight: .semibold))
                            Text(t.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Text(countdown(t.date.timeIntervalSince(s.now)))
                        .font(.system(size: 46, weight: .semibold, design: .rounded)).monospacedDigit()
                        .padding(.leading, 2)
                }
            } else {
                Text(s.loading ? L("Lade Gebetszeiten…") : L("Keine Gebetszeiten vorhanden")).foregroundStyle(.secondary)
            }
        }
    }

    private var prayerGrid: some View {
        let cur = s.current?.date
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(s.today, id: \.vakit.rawValue) { e in
                let isCurrent = cur == e.date
                Tile(radius: 26, padding: 10) {
                    HStack(spacing: 10) {
                        IconCircle(symbol: e.vakit.symbol, active: isCurrent, size: 38)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.vakit.name).font(.system(size: 13, weight: .semibold))
                            Text(hm(e.date)).font(.system(size: 13)).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                .opacity(e.date < s.now && !isCurrent ? 0.55 : 1)
            }
        }
    }

    private var kerahatTile: some View {
        Tile(radius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(s.names.kerahat).font(.system(size: 13, weight: .semibold))
                ForEach(s.kerahat(on: s.now), id: \.start) { k in
                    let active = k.contains(s.now)
                    HStack {
                        Text(L("%@ bis %@", hm(k.start), hm(k.end))).monospacedDigit()
                        Spacer()
                        Text(k.label)
                    }
                    .font(.system(size: 12, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                    .opacity(k.end < s.now ? 0.6 : 1)
                }
            }
        }
    }

    private func updateTile(_ info: UpdateInfo) -> some View {
        Tile(radius: 24, padding: 12) {
            HStack(spacing: 10) {
                IconCircle(symbol: "arrow.down", active: true, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Version %@ ist da", info.version)).font(.system(size: 13, weight: .semibold))
                    Text(u.status ?? info.notes ?? L("Neue Version installieren")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Button(u.busy ? "…" : L("Installieren")) { u.install() }
                    .disabled(u.busy)
                    .controlSize(.small)
            }
        }
    }

    private var settingsTile: some View {
        Tile(radius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(L("Sprache"), selection: $s.lang) {
                    ForEach(AppLang.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                Picker(L("Namen"), selection: $s.names) {
                    ForEach(NameStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                Stepper(L("%@ nach Sonnenaufgang: %d min", s.names.kerahat, s.kSunrise), value: $s.kSunrise, in: 0...90, step: 5)
                Stepper(L("%@ vor %@: %d min", s.names.kerahat, Vakit.ogle.name, s.kNoon), value: $s.kNoon, in: 0...90, step: 5)
                Stepper(L("%@ vor %@: %d min", s.names.kerahat, Vakit.aksam.name, s.kSunset), value: $s.kSunset, in: 0...90, step: 5)
                Toggle(L("Sekunden in der Menüleiste"), isOn: $s.showSeconds)
                Toggle(L("Bei Anmeldung starten"), isOn: $loginItem)
                    .onChange(of: loginItem) { on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                        catch { loginItem = SMAppService.mainApp.status == .enabled }
                    }
                Toggle(L("Updates automatisch installieren"), isOn: $u.auto)
                HStack {
                    Text(L("Version %@", u.currentVersion)).foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Nach Updates suchen")) { u.check(manual: true) }.disabled(u.busy)
                }
                if let st = u.status, u.available == nil { Text(st).font(.caption).foregroundStyle(.secondary) }
            }
            .font(.system(size: 12))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                CircleButton(symbol: "arrow.clockwise", help: L("Neu von IGMG laden")) { s.refresh() }
                    .disabled(s.loading)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.3)) { settingsOpen.toggle(); if settingsOpen { pickerOpen = false } }
                } label: {
                    Text(settingsOpen ? L("Fertig") : L("Einstellungen"))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Glass(cornerRadius: 16))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
                CircleButton(symbol: "power", help: L("Beenden")) { NSApp.terminate(nil) }
            }
            Button {
                NSWorkspace.shared.open(s.city.pageURL)
            } label: {
                Text(L("Quelle IGMG") + (s.lastFetch.map { L(", Stand %@", $0.formatted(.dateTime.day().month(.twoDigits).hour().minute().locale(s.lang.locale))) } ?? ""))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
}

// MARK: - Auto-Update

/// Update-Quelle: GitHub-Repo mit latest.json + Gebetszeiten.zip (siehe release.sh)
let updateManifestURL = ProcessInfo.processInfo.environment["GEBETSZEITEN_UPDATE_URL"].flatMap(URL.init(string:))
    ?? URL(string: "https://raw.githubusercontent.com/tkarakurt-dev/gebetszeiten/main/release/latest.json")!

struct UpdateInfo: Decodable {
    let build: Int
    let version: String
    let url: URL
    let sha256: String
    let notes: String?
}

/// Prüft beim Start und alle 6 Stunden auf eine neue Version, lädt sie, prüft die Prüfsumme,
/// ersetzt die App und startet sie neu.
@MainActor
final class Updater: ObservableObject {
    @Published var available: UpdateInfo?
    @Published var status: String?
    @Published var busy = false
    @Published var auto: Bool { didSet { UserDefaults.standard.set(auto, forKey: "autoUpdate") } }
    private var lastCheck = Date.distantPast

    let currentBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    init() {
        UserDefaults.standard.register(defaults: ["autoUpdate": true])
        auto = UserDefaults.standard.bool(forKey: "autoUpdate")
    }

    func checkIfDue() {
        if Date().timeIntervalSince(lastCheck) > 6 * 3600 { check(manual: false) }
    }

    func check(manual: Bool) {
        guard !busy else { return }
        lastCheck = Date()
        busy = true
        if manual { status = L("Suche nach Updates…") }
        Task {
            defer { busy = false }
            do {
                var req = URLRequest(url: updateManifestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
                req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
                if info.build > currentBuild {
                    available = info
                    status = nil
                    if auto && !manual { busy = false; install() }
                } else {
                    available = nil
                    status = manual ? L("Du hast die neueste Version (%@).", currentVersion) : nil
                }
            } catch {
                if manual { status = L("Update-Prüfung fehlgeschlagen.") }
            }
        }
    }

    func install() {
        guard let info = available, !busy else { return }
        busy = true
        status = L("Lade Version %@…", info.version)
        Task {
            do {
                let (file, _) = try await URLSession.shared.download(from: info.url)
                let data = try Data(contentsOf: file)
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard hash == info.sha256.lowercased() else { throw UpdateError(L("Prüfsumme stimmt nicht")) }

                let work = FileManager.default.temporaryDirectory.appendingPathComponent("gebetszeiten-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let zip = work.appendingPathComponent("update.zip")
                try data.write(to: zip)
                try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.appendingPathComponent("x").path])
                guard let newApp = FileManager.default.enumerator(at: work.appendingPathComponent("x"), includingPropertiesForKeys: nil)?
                        .compactMap({ $0 as? URL }).first(where: { $0.lastPathComponent == "Gebetszeiten.app" }),
                      Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier
                else { throw UpdateError(L("Paket unvollständig")) }

                let target = Bundle.main.bundleURL
                guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
                    throw UpdateError(L("Keine Schreibrechte für %@", target.deletingLastPathComponent().path))
                }
                // Nach dem Beenden: alte App ersetzen, Download-Sperre entfernen, neu starten
                let script = """
                while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
                rm -rf "\(target.path)" && mv "\(newApp.path)" "\(target.path)"
                xattr -dr com.apple.quarantine "\(target.path)" 2>/dev/null
                open "\(target.path)"
                rm -rf "\(work.path)"
                """
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/sh")
                p.arguments = ["-c", script]
                try p.run()
                status = L("Starte neu…")
                NSApp.terminate(nil)
            } catch {
                status = L("Update fehlgeschlagen: %@", (error as? UpdateError)?.message ?? error.localizedDescription)
                busy = false
            }
        }
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw UpdateError(L("Entpacken fehlgeschlagen")) }
    }
}

struct UpdateError: Error { let message: String; init(_ m: String) { message = m } }

// MARK: - Standort

extension Notification.Name {
    static let requestLocation = Notification.Name("gebetszeiten.requestLocation")
}

/// Ermittelt den Standort (WLAN-genau reicht) und stellt die nächste IGMG-Stadt ein.
@MainActor
final class Locator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let store: Store
    private var lastRequest = Date.distantPast

    init(store: Store) {
        self.store = store
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Fragt höchstens alle 20 Minuten neu, außer `force`.
    func update(force: Bool = false) {
        guard store.autoLocation, force || Date().timeIntervalSince(lastRequest) > 20 * 60 else { return }
        lastRequest = Date()
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            store.locationNote = L("Standortzugriff ist aus. Freigeben unter Systemeinstellungen > Datenschutz & Sicherheit > Ortungsdienste.")
        default: start()
        }
    }

    /// Ortung kurz laufen lassen, beim ersten Treffer stoppen (zuverlässiger als requestLocation)
    private func start() {
        manager.startUpdatingLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in self?.manager.stopUpdatingLocation() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        MainActor.assumeIsolated {
            switch m.authorizationStatus {
            case .authorized, .authorizedAlways: if store.autoLocation { start() }
            case .denied, .restricted:
                store.locationNote = L("Standortzugriff ist aus. Freigeben unter Systemeinstellungen > Datenschutz & Sicherheit > Ortungsdienste.")
            default: break
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let loc = locations.last, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 5000 else { return }
            m.stopUpdatingLocation()
            guard store.autoLocation, let hit = Cities.nearest(to: loc) else { return }
            store.locationNote = hit.km < 1.5 ? L("Standort: %@", hit.city.name) : L("Standort: %@, %d km entfernt", hit.city.name, Int(hit.km.rounded()))
            store.setCity(hit.city)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        // "Standort unbekannt" ist vorübergehend, die Ortung läuft weiter
        if (error as? CLError)?.code == .locationUnknown { return }
        MainActor.assumeIsolated {
            m.stopUpdatingLocation()
            store.locationNote = L("Standort gerade nicht bestimmbar, es bleibt %@.", store.city.name)
        }
    }
}

// MARK: - Glas-Fenster unter der Menüleiste

final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    let updater = Updater()
    lazy var locator = Locator(store: store)
    var item: NSStatusItem!
    var panel: GlassPanel!
    var timer: Timer?
    var lastDay = ""
    var outsideClick: Any?

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.imagePosition = .imageLeading

        buildPanel()

        store.refreshIfNeeded()
        locator.update(force: true)
        NotificationCenter.default.addObserver(forName: .requestLocation, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.locator.update(force: true) }
        }
        tick()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.now = Date(); self?.store.refreshIfNeeded(); self?.locator.update(force: true) }
        }
    }

    private func buildPanel() {
        panel = GlassPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false

        let host = NSHostingController(rootView: ContentView(s: store, u: updater))
        host.sizingOptions = [.preferredContentSize]
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = .clear

        // Hülle aus Glas, darin die SwiftUI-Oberfläche
        let glass = makeGlass(cornerRadius: 30)
        if glass.responds(to: NSSelectorFromString("setContentView:")) {
            glass.setValue(host.view, forKey: "contentView")
        } else {
            host.view.translatesAutoresizingMaskIntoConstraints = false
            glass.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: glass.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            ])
        }
        panel.contentView = glass

        // Größe folgt dem Inhalt, Oberkante bleibt unter der Menüleiste
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: host.view, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fitPanel() }
        }
        host.view.postsFrameChangedNotifications = true
        hostView = host.view
        hostController = host
    }

    var hostView: NSView?
    var hostController: NSHostingController<ContentView>?

    private func fitPanel() {
        guard let hv = hostView, let b = item.button, let bw = b.window else { return }
        let anchor = bw.convertToScreen(b.convert(b.bounds, to: nil))
        let screen = bw.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let room = max(300, anchor.minY - 6 - screen.minY - 10)
        if abs(store.maxHeight - room) > 0.5 { store.maxHeight = room; hv.layoutSubtreeIfNeeded() }
        var size = hv.fittingSize
        size.height = min(size.height, room)
        var x = anchor.midX - size.width / 2
        x = min(max(x, screen.minX + 8), screen.maxX - size.width - 8)
        let top = anchor.minY - 6
        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
    }

    func tick() {
        store.now = Date()
        let key = dayKey(store.now)
        if key != lastDay { lastDay = key; store.refreshIfNeeded() }
        updater.checkIfDue()

        let inKerahat = store.activeKerahat != nil
        let img = NSImage(systemSymbolName: inKerahat ? "hourglass" : "moon.stars", accessibilityDescription: "Gebetszeiten")
        img?.isTemplate = true
        item.button?.image = img
        item.button?.attributedTitle = NSAttributedString(string: " " + store.menuTitle, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ])
        if panel.isVisible, let hv = hostView, abs(hv.fittingSize.height - panel.frame.height) > 0.5 { fitPanel() }
    }

    @objc func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        store.refreshIfNeeded()
        locator.update()
        NSApp.activate(ignoringOtherApps: true)
        fitPanel()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; panel.animator().alphaValue = 1 }
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    func hide() {
        if let m = outsideClick { NSEvent.removeMonitor(m); outsideClick = nil }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; panel.animator().alphaValue = 0 }) { [weak self] in
            MainActor.assumeIsolated { self?.panel.orderOut(nil) }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    // Esc schließt das Fenster
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
        if e.keyCode == 53, delegate.panel.isVisible { delegate.hide(); return nil }
        return e
    }
    app.run()
}
