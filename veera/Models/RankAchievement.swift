import Foundation
import SwiftData

// Persisted record of the moment the player first reached each rank.
// We record going forward only — historical achievements before this model
// landed aren't backfilled. The Stats tab's rank-up timeline reads from here.
@Model
final class RankAchievement {
    var id: UUID
    var rankRaw: String
    var achievedAt: Date

    var rank: Rank {
        get { Rank(rawValue: rankRaw) ?? .veera }
        set { rankRaw = newValue.rawValue }
    }

    init(rank: Rank, achievedAt: Date = .now) {
        self.id = UUID()
        self.rankRaw = rank.rawValue
        self.achievedAt = achievedAt
    }
}
