import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]
    @Query(filter: #Predicate<Habit> { !$0.isArchived }) private var habits: [Habit]
    @Query private var completions: [HabitCompletion]
    @Query(sort: \RankAchievement.achievedAt, order: .forward) private var achievements: [RankAchievement]

    @State private var hasAppeared = false
    @State private var segment: Segment = .overview

    enum Segment: String, CaseIterable, Hashable {
        case overview = "Overview"
        case activity = "Activity"
        case progression = "Progression"
    }

    private var player: Player? { players.first }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.obsidian.ignoresSafeArea()
                // Soft gold glow behind the hero card.
                RadialGradient(
                    colors: [Theme.gold.opacity(0.18), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 360
                )
                .ignoresSafeArea(edges: .top)
                .frame(height: 360)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let player {
                            HeroSummaryCard(
                                player: player,
                                xpThisWeek: xpThisWeek,
                                totalCompletions: completions.count
                            )
                        }
                        SegmentedTabBar<Segment>(selection: $segment)
                            .padding(.top, 4)

                        Group {
                            switch segment {
                            case .overview:    overviewSection
                            case .activity:    activitySection
                            case .progression: progressionSection
                            }
                        }
                        .id(segment)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .onAppear { hasAppeared = true }
            }
            .navigationTitle("Stats")
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(Theme.gold)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var overviewSection: some View {
        if hasAppeared {
            VStack(spacing: 14) {
                MetricGrid(metrics: overviewMetrics)
                StatRadarCard(values: statValuesMap)
                StreakByCategoryCard(streaks: streaksByCategory)
            }
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if hasAppeared {
            VStack(spacing: 14) {
                YearHeatmapCard(dailyMap: dailyMap)
                WeeklyXPCard(weeks: weeklyXP)
                StatColumnsCard(columns: statColumns)
            }
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var progressionSection: some View {
        if hasAppeared {
            VStack(spacing: 14) {
                if let player {
                    NextRankCard(player: player)
                }
                RankLadderCard(
                    currentLevel: player.map { XPEngine.level(for: $0.totalXP) } ?? 1,
                    achievements: rankMilestones
                )
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ProgressView().tint(Theme.gold).padding(.vertical, 80)
    }

    // MARK: - Derived data

    private var weeklyXP: [StatsAggregator.WeeklyXP] {
        StatsAggregator.weeklyXP(completions: completions)
    }

    private var statColumns: [StatsAggregator.StatColumn] {
        guard let player else { return [] }
        return StatsAggregator.statColumns(player: player)
    }

    private var streaksByCategory: [StatsAggregator.CategoryStreak] {
        StatsAggregator.longestStreakByCategory(habits: habits)
    }

    private var rankMilestones: [StatsAggregator.RankMilestone] {
        StatsAggregator.rankTimeline(achievements: achievements)
    }

    private var dailyMap: [Date: Int] {
        let year = Calendar.current.component(.year, from: .now)
        return StatsAggregator.dailyXPMap(forYear: year, in: context)
    }

    private var statValuesMap: [StatCategory: Int] {
        StatsAggregator.statValues(in: context)
    }

    private var xpThisWeek: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        let weekStart = calendar.date(from: components) ?? .now
        return completions
            .filter { $0.completedAt >= weekStart }
            .reduce(0) { $0 + $1.xpAwarded }
    }

    private var overviewMetrics: [MetricTileData] {
        guard let player else { return [] }
        let level = XPEngine.level(for: player.totalXP)
        let topStat = StatCategory.allCases.max(by: { player.points(for: $0) < player.points(for: $1) }) ?? .strength
        return [
            MetricTileData(value: "\(player.currentStreak)", label: "Streak", icon: "flame.fill", caption: "consecutive days"),
            MetricTileData(value: "+\(xpThisWeek)", label: "This week", icon: "chart.line.uptrend.xyaxis", caption: "XP earned"),
            MetricTileData(value: "\(level)", label: "Level", icon: "crown.fill", caption: Rank.rank(forLevel: level).rawValue),
            MetricTileData(value: topStat.rawValue, label: "Top stat", icon: topStat.symbol, caption: "\(player.points(for: topStat)) pts")
        ]
    }
}

// MARK: - Metric tile data

private struct MetricTileData: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    let icon: String
    let caption: String
}

private struct MetricGrid: View {
    let metrics: [MetricTileData]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(metrics) { metric in
                MetricTile(
                    value: metric.value,
                    label: metric.label,
                    icon: metric.icon,
                    caption: metric.caption
                )
            }
        }
    }
}

// MARK: - Hero summary

private struct HeroSummaryCard: View {
    let player: Player
    let xpThisWeek: Int
    let totalCompletions: Int

    private var level: Int { XPEngine.level(for: player.totalXP) }
    private var rank: Rank { Rank.rank(forLevel: level) }
    private var progress: Double { XPEngine.progressThroughCurrentLevel(totalXP: player.totalXP) }
    private var xpToNext: Int { XPEngine.xpRemainingInCurrentLevel(totalXP: player.totalXP) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                LevelBadge(level: level, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.displayName.uppercased())
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .tracking(3)
                        .foregroundStyle(Theme.parchment)
                    Text(rank.rawValue.uppercased())
                        .font(Fonts.caption)
                        .tracking(2.5)
                        .foregroundStyle(Theme.gold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(player.totalXP)")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.gold)
                    Text("XP TOTAL")
                        .font(Fonts.micro)
                        .tracking(2)
                        .foregroundStyle(Theme.mutedGold)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LEVEL \(level)")
                        .font(Fonts.micro)
                        .tracking(2)
                        .foregroundStyle(Theme.mutedGold)
                    Spacer()
                    Text("\(xpToNext) XP TO NEXT")
                        .font(Fonts.micro)
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedGold)
                }
                GoldProgressBar(progress: progress)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .heroCard()
    }
}

// MARK: - Weekly XP

private struct WeeklyXPCard: View {
    let weeks: [StatsAggregator.WeeklyXP]

    private var totalLast8: Int { weeks.reduce(0) { $0 + $1.totalXP } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Weekly XP", caption: "Last 8 weeks · \(totalLast8) XP")

            if weeks.allSatisfy({ $0.totalXP == 0 }) {
                EmptyHintRow(text: "No XP earned in the last 8 weeks.")
            } else {
                Chart(weeks) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("XP", week.totalXP)
                    )
                    .foregroundStyle(Theme.goldGradient)
                    .cornerRadius(5)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(),
                                       collisionResolution: .greedy)
                            .font(Fonts.micro)
                            .foregroundStyle(Theme.mutedGold)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.border.opacity(0.6))
                        AxisValueLabel()
                            .font(Fonts.micro)
                            .foregroundStyle(Theme.mutedGold)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

// MARK: - Stat columns

private struct StatColumnsCard: View {
    let columns: [StatsAggregator.StatColumn]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Stat distribution", caption: "Current points per stat")

            if columns.isEmpty {
                EmptyHintRow(text: "No player yet.")
            } else {
                Chart(columns) { column in
                    BarMark(
                        x: .value("Stat", column.category.rawValue),
                        y: .value("Points", column.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Theme.statColor(value: column.value).opacity(0.95),
                                Theme.statColor(value: column.value).opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(Fonts.micro)
                            .foregroundStyle(Theme.mutedGold)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.border.opacity(0.6))
                        AxisValueLabel()
                            .font(Fonts.micro)
                            .foregroundStyle(Theme.mutedGold)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

// MARK: - Longest streak per category

private struct StreakByCategoryCard: View {
    let streaks: [StatsAggregator.CategoryStreak]

    private var maxStreak: Int { max(1, streaks.map(\.longest).max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Longest streaks", caption: "Best run per stat")

            VStack(spacing: 10) {
                ForEach(streaks) { entry in
                    streakRow(entry)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }

    private func streakRow(_ entry: StatsAggregator.CategoryStreak) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
            Text(entry.category.displayName.uppercased())
                .font(Fonts.micro)
                .tracking(1.5)
                .foregroundStyle(Theme.mutedGold)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.obsidian)
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 0.5))
                    Capsule()
                        .fill(entry.longest > 0 ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.clear))
                        .frame(width: geo.size.width * (Double(entry.longest) / Double(maxStreak)))
                }
            }
            .frame(height: 6)
            Text("\(entry.longest)")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(entry.longest > 0 ? Theme.gold : Theme.dim)
                .frame(width: 36, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

// MARK: - Shared empty hint

private struct EmptyHintRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Fonts.body)
            .foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 22)
    }
}

#Preview {
    let schema = Schema([
        Player.self, Habit.self, HabitCompletion.self, TaskItem.self, Reminder.self,
        RankAchievement.self
    ])
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    // swiftlint:disable:next redundant_discardable_let
    let _ = {
        let context = container.mainContext
        let player = Player(displayName: "Kirthik", totalXP: 1240)
        player.strXP = 380
        player.intXP = 520
        player.vitXP = 95
        player.dscXP = 240
        player.wilXP = 180
        player.currentStreak = 12
        context.insert(player)
        context.insert(RankAchievement(rank: .veera, achievedAt: .now.addingTimeInterval(-86400 * 90)))
        context.insert(RankAchievement(rank: .maravan, achievedAt: .now.addingTimeInterval(-86400 * 30)))
        context.insert(RankAchievement(rank: .thalapathi, achievedAt: .now.addingTimeInterval(-86400 * 5)))
    }()

    StatsView()
        .preferredColorScheme(.dark)
        .modelContainer(container)
}
