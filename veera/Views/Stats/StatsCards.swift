import SwiftUI

// Larger Stats cards extracted into their own file so `StatsView.swift` stays
// under SwiftLint's file-length budget. All structs here are scoped `internal`
// because they are only referenced from `StatsView.swift`; we don't want them
// in any other tab.

// MARK: - Year heatmap (modernized)

struct YearHeatmapCard: View {
    let dailyMap: [Date: Int]

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    private let calendar = Calendar.current
    private let year = Calendar.current.component(.year, from: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Year · XP heatmap", caption: "\(year) · \(totalXP) XP total")

            HStack(alignment: .top, spacing: 6) {
                weekdayColumn
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        monthLabels
                        canvas
                    }
                }
                .scrollClipDisabled()
            }

            legend
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }

    private var totalXP: Int { dailyMap.values.reduce(0, +) }

    private var weekdayColumn: some View {
        VStack(alignment: .trailing, spacing: cellSpacing) {
            Color.clear.frame(width: 1, height: 12)
            ForEach(0..<7, id: \.self) { row in
                let label = ["S", "M", "T", "W", "T", "F", "S"][row]
                Text(row % 2 == 0 ? label : " ")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 10, height: cellSize)
            }
        }
    }

    private struct MonthEntry: Identifiable {
        let month: Int
        let label: String
        let weeks: Int
        var id: Int { month }
    }

    private var monthLabels: some View {
        HStack(spacing: 0) {
            ForEach(monthOffsets) { entry in
                Text(entry.label)
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Theme.mutedGold)
                    .frame(width: CGFloat(entry.weeks) * (cellSize + cellSpacing), alignment: .leading)
            }
        }
        .frame(height: 12)
    }

    private var monthOffsets: [MonthEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var result: [MonthEntry] = []
        for month in 1...12 {
            guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let range = calendar.range(of: .day, in: .month, for: first) else { continue }
            let dayCount = range.count
            let weeks = max(1, Int(round(Double(dayCount) / 7.0)))
            result.append(MonthEntry(month: month, label: formatter.string(from: first).uppercased(), weeks: weeks))
        }
        return result
    }

    private var canvas: some View {
        Canvas { ctx, _ in
            let maxXP = max(1, dailyMap.values.max() ?? 1)
            guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return }
            let firstWeekday = calendar.component(.weekday, from: jan1) - 1
            for dayOffset in 0..<365 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: jan1) else { continue }
                if calendar.component(.year, from: day) != year { break }
                let cellIndex = dayOffset + firstWeekday
                let week = cellIndex / 7
                let weekday = cellIndex % 7
                let normalized = calendar.startOfDay(for: day)
                let xp = dailyMap[normalized] ?? 0
                let rect = CGRect(
                    x: CGFloat(week) * (cellSize + cellSpacing),
                    y: CGFloat(weekday) * (cellSize + cellSpacing),
                    width: cellSize, height: cellSize
                )
                if xp == 0 {
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 2.5),
                        with: .color(Theme.surface)
                    )
                    ctx.stroke(
                        Path(roundedRect: rect, cornerRadius: 2.5),
                        with: .color(Theme.border.opacity(0.6)),
                        lineWidth: 0.5
                    )
                } else {
                    let intensity = (Double(xp) / Double(maxXP)) * 0.75 + 0.25
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 2.5),
                        with: .color(Theme.gold.opacity(intensity))
                    )
                }
            }
        }
        .frame(width: 54 * (cellSize + cellSpacing), height: 7 * (cellSize + cellSpacing))
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("LESS")
                .font(.system(size: 8, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Theme.dim)
            ForEach([0.15, 0.4, 0.65, 0.9], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.gold.opacity(opacity))
                    .frame(width: 10, height: 10)
            }
            Text("MORE")
                .font(.system(size: 8, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Theme.dim)
            Spacer()
        }
    }
}

// MARK: - Stat radar (modernized)

struct StatRadarCard: View {
    let values: [StatCategory: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Stat radar", caption: "Strength · Intellect · Vitality · Discipline · Will")

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: side / 2)
                let radius = side / 2 - 30
                let categories = StatCategory.allCases
                let displayMax = max(50, values.values.max() ?? 50)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.gold.opacity(0.18), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)

                    Canvas { ctx, _ in
                        for fraction in stride(from: 0.25, through: 1.0, by: 0.25) {
                            var path = Path()
                            let ringRadius = radius * fraction
                            for index in 0..<categories.count {
                                let point = Self.vertex(at: index, of: categories.count, center: center, radius: ringRadius)
                                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                            }
                            path.closeSubpath()
                            ctx.stroke(path, with: .color(Theme.border.opacity(0.7)), lineWidth: 1)
                        }
                        for index in 0..<categories.count {
                            let outer = Self.vertex(at: index, of: categories.count, center: center, radius: radius)
                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: outer)
                            ctx.stroke(path, with: .color(Theme.border), lineWidth: 1)
                        }
                        var poly = Path()
                        for (index, category) in categories.enumerated() {
                            let value = Double(values[category] ?? 0)
                            let scaled = radius * CGFloat(min(1, value / Double(displayMax)))
                            let point = Self.vertex(at: index, of: categories.count, center: center, radius: scaled)
                            if index == 0 { poly.move(to: point) } else { poly.addLine(to: point) }
                        }
                        poly.closeSubpath()
                        ctx.fill(
                            poly,
                            with: .linearGradient(
                                Gradient(colors: [Theme.gold.opacity(0.6), Theme.gold.opacity(0.2)]),
                                startPoint: CGPoint(x: center.x, y: center.y - radius),
                                endPoint: CGPoint(x: center.x, y: center.y + radius)
                            )
                        )
                        ctx.stroke(poly, with: .color(Theme.gold), lineWidth: 1.5)
                        for (index, category) in categories.enumerated() {
                            let value = Double(values[category] ?? 0)
                            let scaled = radius * CGFloat(min(1, value / Double(displayMax)))
                            let point = Self.vertex(at: index, of: categories.count, center: center, radius: scaled)
                            let dot = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                            ctx.fill(Path(ellipseIn: dot), with: .color(Theme.gold))
                        }
                    }

                    ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                        let labelRadius = radius + 20
                        let point = Self.vertex(at: index, of: categories.count, center: center, radius: labelRadius)
                        VStack(spacing: 2) {
                            Text(category.rawValue)
                                .font(Fonts.micro)
                                .tracking(1.5)
                                .foregroundStyle(Theme.mutedGold)
                            Text("\(values[category] ?? 0)")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.gold)
                        }
                        .position(point)
                    }
                }
            }
            .frame(height: 260)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }

    private static func vertex(at index: Int, of total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -.pi / 2 + (2 * .pi * CGFloat(index) / CGFloat(total))
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

// MARK: - Rank ladder

struct RankLadderCard: View {
    let currentLevel: Int
    let achievements: [StatsAggregator.RankMilestone]

    private enum NodeStatus {
        case earned(Date?)
        case current(Date?)
        case locked(Int)
    }

    private var currentRank: Rank { Rank.rank(forLevel: currentLevel) }

    private func status(for rank: Rank) -> NodeStatus {
        let earnedDate = achievements.first(where: { $0.rank == rank })?.achievedAt
        if rank == currentRank { return .current(earnedDate) }
        if rank.minLevel <= currentLevel { return .earned(earnedDate) }
        return .locked(rank.minLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Rank ladder", caption: "Veera → Maaveeran")
            VStack(spacing: 0) {
                ForEach(Array(Rank.allCases.enumerated()), id: \.element) { idx, rank in
                    rankRow(rank, isFirst: idx == 0, isLast: idx == Rank.allCases.count - 1)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }

    @ViewBuilder
    private func rankRow(_ rank: Rank, isFirst: Bool, isLast: Bool) -> some View {
        let nodeStatus = status(for: rank)
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : connectorColor(above: rank))
                    .frame(width: 1.5, height: 12)
                node(for: nodeStatus)
                Rectangle()
                    .fill(isLast ? Color.clear : connectorColor(below: rank))
                    .frame(width: 1.5, height: 30)
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    // Pulls through the masking helper so a locked secret
                    // can never render its real title or level here.
                    let display = Rank.display(for: rank, viewerLevel: currentLevel)
                    if display.isMasked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.mutedGold)
                    }
                    Text(display.title.uppercased())
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .tracking(2.5)
                        .foregroundStyle(textColor(for: nodeStatus))
                    if case .current = nodeStatus {
                        Text("CURRENT")
                            .font(.system(size: 8, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(Theme.obsidian)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.goldGradient))
                    }
                }
                Text(subtitle(for: rank, status: nodeStatus))
                    .font(Fonts.micro)
                    .tracking(1)
                    .foregroundStyle(Theme.mutedGold)
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func node(for status: NodeStatus) -> some View {
        switch status {
        case .earned:
            Rectangle()
                .fill(Theme.goldGradient)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(45))
                .frame(width: 22, height: 22)
        case .current:
            ZStack {
                Rectangle()
                    .stroke(Theme.gold, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(45))
                Rectangle()
                    .fill(Theme.goldGradient)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(45))
            }
            .frame(width: 30, height: 30)
            .shadow(color: Theme.gold.opacity(0.6), radius: 8, x: 0, y: 0)
        case .locked:
            Rectangle()
                .stroke(Theme.border, lineWidth: 1)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(45))
                .frame(width: 22, height: 22)
        }
    }

    private func subtitle(for rank: Rank, status: NodeStatus) -> String {
        // Locked secrets reveal NOTHING — not the level required, not Tamil,
        // not meaning. Just the mystery cue.
        if rank.isSecret && !rank.isUnlocked(at: currentLevel) {
            return "Sealed"
        }
        switch status {
        case .earned(let date):
            if let date {
                return "Earned \(date.formatted(.dateTime.month(.abbreviated).day().year()))"
            }
            return "Earned"
        case .current(let date):
            if let date {
                return "Current · since \(date.formatted(.dateTime.month(.abbreviated).day().year()))"
            }
            return "Current"
        case .locked(let level):
            return "Level \(level) required"
        }
    }

    private func textColor(for status: NodeStatus) -> Color {
        switch status {
        case .earned:  return Theme.parchment
        case .current: return Theme.gold
        case .locked:  return Theme.dim
        }
    }

    private func connectorColor(above rank: Rank) -> Color {
        rank.minLevel <= currentLevel ? Theme.gold.opacity(0.6) : Theme.border
    }

    private func connectorColor(below rank: Rank) -> Color {
        guard let next = Rank.allCases.first(where: { $0.minLevel > rank.minLevel }) else {
            return Theme.border
        }
        return next.minLevel <= currentLevel ? Theme.gold.opacity(0.6) : Theme.border
    }
}

// MARK: - Next rank progress

struct NextRankCard: View {
    let player: Player

    private var level: Int { XPEngine.level(for: player.totalXP) }
    private var currentRank: Rank { Rank.rank(forLevel: level) }

    private var nextRank: Rank? {
        Rank.allCases.first(where: { $0.minLevel > level })
    }

    var body: some View {
        // Mask the next rank's identity if it's a still-locked secret —
        // the SectionLabel caption and the "NEXT · …" pill both pull from
        // RankDisplay, never from rawValue directly.
        let nextDisplay = nextRank.map { Rank.display(for: $0, viewerLevel: level) }

        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(
                "Ascent",
                caption: nextDisplay == nil
                    ? "You stand at the summit"
                    : "\(currentRank.rawValue) → \(nextDisplay?.title ?? "")"
            )

            HStack(spacing: 16) {
                LevelBadge(level: level, size: 44)
                if let next = nextRank, let display = nextDisplay {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if display.isMasked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.mutedGold)
                            }
                            Text("NEXT · \(display.title.uppercased())")
                                .font(Fonts.micro)
                                .tracking(2)
                                .foregroundStyle(Theme.mutedGold)
                        }
                        // For masked secrets, hide the concrete level/XP gap —
                        // it would leak the threshold.
                        if display.isMasked {
                            Text("THE PATH BEYOND")
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.gold)
                        } else {
                            Text("\(remainingLevels(to: next)) LEVELS · \(remainingXP(to: next)) XP")
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.gold)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentRank.rawValue.uppercased())
                            .font(Fonts.title)
                            .tracking(3)
                            .foregroundStyle(Theme.gold)
                        Text("The summit holds.")
                            .font(Fonts.micro)
                            .tracking(1.5)
                            .foregroundStyle(Theme.mutedGold)
                    }
                }
                Spacer()
            }

            if let next = nextRank, !(nextDisplay?.isMasked ?? false) {
                GoldProgressBar(progress: progress(to: next), height: 10)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }

    private func remainingLevels(to rank: Rank) -> Int {
        max(0, rank.minLevel - level)
    }

    private func remainingXP(to rank: Rank) -> Int {
        let xpAtRankStart = (rank.minLevel - 1) * XPEngine.xpPerLevel
        return max(0, xpAtRankStart - player.totalXP)
    }

    private func progress(to rank: Rank) -> Double {
        let start = currentRank.minLevel
        let end = rank.minLevel
        let span = Double(max(1, end - start))
        let traveled = Double(level - start) + XPEngine.progressThroughCurrentLevel(totalXP: player.totalXP)
        return min(1.0, max(0.0, traveled / span))
    }
}
