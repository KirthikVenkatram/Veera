import Foundation
import SwiftData

@Model
final class Player {
    // MARK: - Identity
    var id: UUID
    var displayName: String           // shown on home screen ("SOVEREIGN" in the mockup)
    var createdAt: Date

    // MARK: - Progression
    var totalXP: Int                  // lifetime XP earned
    var currentStreak: Int            // consecutive days with at least one habit completed
    var longestStreak: Int            // record-keeping
    var lastActiveDate: Date?         // used to decide if streak should reset
    var lastMissCheckedDate: Date?    // marks the day the missed-habit check already ran;
                                      // exists separately from lastActiveDate so the streak
                                      // logic isn't tangled with penalty deduplication

    // MARK: - Stat points
    // We store stat XP separately from total XP so each stat can level independently.
    // Display value = sqrt(statXP / 5) or similar — computed in XPEngine, not stored.
    var strXP: Int
    var intXP: Int
    var vitXP: Int
    var dscXP: Int
    var wilXP: Int

    // MARK: - Preferences
    // Stored as raw String because @Model doesn't support enums directly in older SwiftData.
    // We expose a computed property to keep callers clean.
    var difficultyRaw: String

    var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .soft }
        set { difficultyRaw = newValue.rawValue }
    }

    // MARK: - Init
    // Default values let SwiftData create a Player with just `Player()`.
    // We use this in PersistenceController.bootstrapPlayerIfNeeded().
    init(
        displayName: String = "Veera",
        totalXP: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        difficulty: Difficulty = .soft
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.createdAt = .now
        self.totalXP = totalXP
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = nil
        self.strXP = 0
        self.intXP = 0
        self.vitXP = 0
        self.dscXP = 0
        self.wilXP = 0
        self.difficultyRaw = difficulty.rawValue
    }

    // MARK: - Helpers
    // Convenience for adding XP to a specific stat. Doesn't compute level — XPEngine does that.
    func addXP(_ amount: Int, to category: StatCategory) {
        totalXP += amount
        switch category {
        case .strength:   strXP += amount
        case .intellect:  intXP += amount
        case .vitality:   vitXP += amount
        case .discipline: dscXP += amount
        case .will:       wilXP += amount
        }
    }

    // Inverse of addXP, clamped at 0 so an undo can never drop XP below zero
    // even if the user has lost XP since the original award (e.g. hard-mode penalty).
    func removeXP(_ amount: Int, from category: StatCategory) {
        totalXP = max(0, totalXP - amount)
        switch category {
        case .strength:   strXP = max(0, strXP - amount)
        case .intellect:  intXP = max(0, intXP - amount)
        case .vitality:   vitXP = max(0, vitXP - amount)
        case .discipline: dscXP = max(0, dscXP - amount)
        case .will:       wilXP = max(0, wilXP - amount)
        }
    }

    // For showing the stat row on the home screen.
    func points(for category: StatCategory) -> Int {
        switch category {
        case .strength:   return strXP
        case .intellect:  return intXP
        case .vitality:   return vitXP
        case .discipline: return dscXP
        case .will:       return wilXP
        }
    }
}
