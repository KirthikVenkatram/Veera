import Foundation

enum XPEngine {
    static let xpPerLevel = 100
    static let hardModeMissPenalty = 10

    static func level(for totalXP: Int) -> Int {
        max(1, (max(0, totalXP) / xpPerLevel) + 1)
    }

    static func xpIntoCurrentLevel(totalXP: Int) -> Int {
        max(0, totalXP) % xpPerLevel
    }

    static func xpRemainingInCurrentLevel(totalXP: Int) -> Int {
        xpPerLevel - xpIntoCurrentLevel(totalXP: totalXP)
    }

    static func progressThroughCurrentLevel(totalXP: Int) -> Double {
        Double(xpIntoCurrentLevel(totalXP: totalXP)) / Double(xpPerLevel)
    }

    static func statLevel(for statXP: Int) -> Int {
        max(1, Int((Double(max(0, statXP)) / 25.0).squareRoot()) + 1)
    }

    static func awardHabit(_ habit: Habit, to player: Player) {
        player.addXP(habit.xpReward, to: habit.category)
    }

    static func awardTask(_ task: TaskItem, to player: Player) {
        player.addXP(task.xpReward, to: task.category)
    }

    // Inverse of awardHabit — used when the user undoes a completion.
    // Clamps both total and per-stat XP at 0 so undoing more than was ever
    // awarded can't push the player into negative territory.
    static func revokeHabit(_ habit: Habit, from player: Player) {
        player.removeXP(habit.xpReward, from: habit.category)
    }

    static func revokeTask(_ task: TaskItem, from player: Player) {
        player.removeXP(task.xpReward, from: task.category)
    }

    static func applyMissPenalty(to player: Player, missedCount: Int) {
        guard player.difficulty == .hard, missedCount > 0 else { return }
        player.totalXP = max(0, player.totalXP - (missedCount * hardModeMissPenalty))
    }
}
