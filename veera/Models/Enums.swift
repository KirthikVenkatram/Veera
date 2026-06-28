import Foundation
import SwiftData

// MARK: - StatCategory
// The five stats your habits feed into. Mapped to the home screen stat row.
// Each habit belongs to exactly one category, and completing it grants XP to that stat.
//
// Why these five:
// - STR (Strength)   — physical training, gym, sports
// - INT (Intellect)  — reading, study, learning, work
// - VIT (Vitality)   — sleep, water, nutrition, health
// - DSC (Discipline) — meditation, no-IG, no-Shorts, focus, cold showers
// - WIL (Will)       — willpower / habit consistency itself; gets a bonus when you maintain streaks
//
// You can rename these later without breaking data because the rawValue stays stable.
nonisolated enum StatCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case strength      = "STR"
    case intellect     = "INT"
    case vitality      = "VIT"
    case discipline    = "DSC"
    case will          = "WIL"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength:   return "Strength"
        case .intellect:  return "Intellect"
        case .vitality:   return "Vitality"
        case .discipline: return "Discipline"
        case .will:       return "Will"
        }
    }

    // SF Symbol name for each stat — used in stat row and habit picker.
    var symbol: String {
        switch self {
        case .strength:   return "dumbbell.fill"
        case .intellect:  return "book.closed.fill"
        case .vitality:   return "heart.fill"
        case .discipline: return "flame.fill"
        case .will:       return "bolt.fill"
        }
    }
}

// MARK: - Cadence
// How often a habit repeats. Daily is the most common; weekly is for things like
// "go to the temple every Sunday"; custom lets you pick specific weekdays.
nonisolated enum Cadence: Codable, Equatable, Hashable, Sendable {
    case daily
    case weekly                              // any single day per week
    case customDays(Set<Weekday>)            // e.g. Mon/Wed/Fri

    private enum CodingKeys: String, CodingKey {
        case kind
        case days
    }

    private enum Kind: String, Codable {
        case daily
        case weekly
        case customDays
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .daily:
            self = .daily
        case .weekly:
            self = .weekly
        case .customDays:
            let rawDays = try container.decode([Weekday].self, forKey: .days)
            self = .customDays(Set(rawDays))
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .daily:
            try container.encode(Kind.daily, forKey: .kind)
        case .weekly:
            try container.encode(Kind.weekly, forKey: .kind)
        case .customDays(let days):
            try container.encode(Kind.customDays, forKey: .kind)
            try container.encode(days.sorted { $0.rawValue < $1.rawValue }, forKey: .days)
        }
    }

    // Does this cadence require completion on the given date?
    // Used by the home screen to decide which habits to show today.
    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekly:
            return true   // simplified — we'll refine this in V2 if needed
        case .customDays(let days):
            let weekday = Weekday(date: date, calendar: calendar)
            return days.contains(weekday)
        }
    }

    // Human-readable cadence — surfaced in HabitDetailView.
    // Examples: "Every day", "Weekly", "Mondays, Wednesdays, Fridays".
    var displaySummary: String {
        switch self {
        case .daily:
            return "Every day"
        case .weekly:
            return "Weekly"
        case .customDays(let days):
            guard !days.isEmpty else { return "No days selected" }
            let sorted = days.sorted { $0.rawValue < $1.rawValue }
            return sorted.map { "\($0.fullName)s" }.joined(separator: ", ")
        }
    }
}

// MARK: - Weekday
// Mon..Sun as a Codable enum. Mirrors Calendar.Component.weekday (1=Sun..7=Sat),
// but we store with Mon=1 for ISO-friendliness. Conversion happens in init(date:).
nonisolated enum Weekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: Int { rawValue }

    init(date: Date, calendar: Calendar = .current) {
        // Calendar.Component.weekday: 1=Sunday..7=Saturday
        // We map: Sun=7, Mon=1, Tue=2, ... Sat=6
        let comp = calendar.component(.weekday, from: date)
        switch comp {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: self = .monday   // unreachable
        }
    }

    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    // Single-letter label used by the 7-day heatmap row in HabitDetailView.
    // T/T and S/S collisions are intentional; matches the convention iOS
    // Health and similar trackers use.
    var letter: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }
}

// MARK: - Difficulty
// V1 ships with both modes, gated by a single toggle in Settings.
// Soft mode is the default — kinder on bad days, better for long-term retention.
// Hard mode is opt-in for when you want the penalty pressure.
nonisolated enum Difficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case soft        // streak resets on miss, no XP loss
    case hard        // streak resets AND XP penalty on miss

    var id: String { rawValue }
    var displayName: String { self == .soft ? "Soft mode" : "Hard mode" }
}

// MARK: - Rank
// The progression ladder, all Tamil-rooted. Eight ranks total; the last three
// are SECRET — they remain masked everywhere ("?????" + lock glyph) until the
// player crosses their minimum level. Per-rank data lives on the case itself
// so thresholds aren't duplicated across the codebase.
nonisolated enum Rank: String, Codable, CaseIterable, Identifiable, Sendable {
    case veera         = "Veera"           // 1–3   • வீர • the brave
    case maravan       = "Maravan"         // 4–6   • மறவன் • warrior
    case sooran        = "Sooran"          // 7–9   • சூரன் • the valiant
    case thalapathi    = "Thalapathi"      // 10–13 • தளபதி • commander
    case maaveeran     = "Maaveeran"       // 14–20 • மாவீரன் • great hero
    case vendhan       = "Vendhan"         // 21–27 • வேந்தன் • crowned king        — SECRET
    case vetrivendhan  = "Vetrivendhan"    // 28–36 • வெற்றிவேந்தன் • victorious king — SECRET
    case sakkaravarthi = "Sakkaravarthi"   // 37+   • சக்கரவர்த்தி • emperor         — SECRET

    var id: String { rawValue }

    var tamilTitle: String {
        switch self {
        case .veera:         return "வீர"
        case .maravan:       return "மறவன்"
        case .sooran:        return "சூரன்"
        case .thalapathi:    return "தளபதி"
        case .maaveeran:     return "மாவீரன்"
        case .vendhan:       return "வேந்தன்"
        case .vetrivendhan:  return "வெற்றிவேந்தன்"
        case .sakkaravarthi: return "சக்கரவர்த்தி"
        }
    }

    var meaning: String {
        switch self {
        case .veera:         return "the brave"
        case .maravan:       return "warrior"
        case .sooran:        return "the valiant"
        case .thalapathi:    return "commander"
        case .maaveeran:     return "great hero"
        case .vendhan:       return "crowned king"
        case .vetrivendhan:  return "victorious king"
        case .sakkaravarthi: return "emperor"
        }
    }

    var minLevel: Int {
        switch self {
        case .veera:         return 1
        case .maravan:       return 4
        case .sooran:        return 7
        case .thalapathi:    return 10
        case .maaveeran:     return 14
        case .vendhan:       return 21
        case .vetrivendhan:  return 28
        case .sakkaravarthi: return 37
        }
    }

    // nil for the open-ended summit. Otherwise the inclusive upper bound.
    var maxLevel: Int? {
        switch self {
        case .veera:         return 3
        case .maravan:       return 6
        case .sooran:        return 9
        case .thalapathi:    return 13
        case .maaveeran:     return 20
        case .vendhan:       return 27
        case .vetrivendhan:  return 36
        case .sakkaravarthi: return nil
        }
    }

    var isSecret: Bool {
        switch self {
        case .vendhan, .vetrivendhan, .sakkaravarthi: return true
        default: return false
        }
    }

    // One-line copy shown on the unlock reveal. Visible ranks get nil — their
    // level-up overlay just shows the title.
    var unlockBlurb: String? {
        switch self {
        case .vendhan:       return "A hero no longer — a crown."
        case .vetrivendhan:  return "The crown, unbroken in war."
        case .sakkaravarthi: return "Sovereign of all under the wheel."
        default: return nil
        }
    }

    // Log-safe identifier (e.g. "vendhan"). Use this in OSLog so a secret
    // never enters logs as its display title before the user has unlocked it.
    var caseName: String { String(describing: self) }

    var romanLevelRange: String {
        let from = Self.roman(minLevel)
        if let maxLevel {
            return "LV. \(from)–\(Self.roman(maxLevel))"
        }
        return "LV. \(from)+"
    }

    func isUnlocked(at viewerLevel: Int) -> Bool {
        viewerLevel >= minLevel
    }

    // Single source of truth — every threshold check goes through this.
    static func rank(forLevel level: Int) -> Self {
        allCases.last { $0.minLevel <= level } ?? .veera
    }

    private static func roman(_ value: Int) -> String {
        let table: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"),
            (90, "XC"), (50, "L"), (40, "XL"), (10, "X"),
            (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var remainder = max(0, value)
        var result = ""
        for (number, symbol) in table {
            while remainder >= number {
                result += symbol
                remainder -= number
            }
        }
        return result.isEmpty ? "0" : result
    }
}

// Data-boundary masking. Views consume `RankDisplay`, not `Rank`, when a
// secret might still be locked. The masked variant carries no title, no Tamil,
// no level info — there's literally no path for a locked secret's real name
// to reach the view or its accessibility label.
struct RankDisplay: Equatable, Sendable {
    let title: String
    let tamil: String?
    let meaning: String?
    let levelRange: String?
    let isMasked: Bool
}

extension Rank {
    static func display(for rank: Rank, viewerLevel: Int) -> RankDisplay {
        if rank.isSecret && !rank.isUnlocked(at: viewerLevel) {
            return RankDisplay(
                title: "?????",
                tamil: nil,
                meaning: nil,
                levelRange: nil,
                isMasked: true
            )
        }
        return RankDisplay(
            title: rank.rawValue,
            tamil: rank.tamilTitle,
            meaning: rank.meaning,
            levelRange: rank.romanLevelRange,
            isMasked: false
        )
    }
}

// MARK: - ReminderRepeat
// Used by standalone Reminder model — separate from Habit Cadence because
// reminders are simpler (no XP, no streak, just a notification).
nonisolated enum ReminderRepeat: String, Codable, CaseIterable, Identifiable, Sendable {
    case once
    case daily
    case weekly

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .once:   return "Once"
        case .daily:  return "Every day"
        case .weekly: return "Every week"
        }
    }
}
