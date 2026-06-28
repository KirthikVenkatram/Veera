import Foundation
import Testing
@testable import veera

struct ProgressionTests {
    @Test func levelUsesOneHundredXPBands() {
        #expect(XPEngine.level(for: 0) == 1)
        #expect(XPEngine.level(for: 99) == 1)
        #expect(XPEngine.level(for: 100) == 2)
        #expect(XPEngine.level(for: 2400) == 25)
    }

    @Test func rankLadderMapsLevelsToCurrentRanks() {
        #expect(Rank.rank(forLevel: 1) == .veera)
        #expect(Rank.rank(forLevel: 5) == .maravan)
        #expect(Rank.rank(forLevel: 10) == .thalapathi)
        #expect(Rank.rank(forLevel: 15) == .maaveeran)
        #expect(Rank.rank(forLevel: 25) == .vendhan)
    }

    @Test func awardingHabitAddsTotalAndStatXP() {
        let player = Player()
        let habit = Habit(name: "Train", xpReward: 15, category: .strength)

        XPEngine.awardHabit(habit, to: player)

        #expect(player.totalXP == 15)
        #expect(player.strXP == 15)
        #expect(player.intXP == 0)
    }

    @Test func hardModePenaltyNeverDropsBelowZero() {
        let player = Player(totalXP: 12, difficulty: .hard)

        XPEngine.applyMissPenalty(to: player, missedCount: 2)

        #expect(player.totalXP == 0)
    }

    @Test func awardingTaskAddsTotalAndStatXP() {
        let player = Player()
        let task = TaskItem(title: "Renew passport", xpReward: 50, category: .will)

        XPEngine.awardTask(task, to: player)

        #expect(player.totalXP == 50)
        #expect(player.wilXP == 50)
        #expect(player.strXP == 0)
    }
}
