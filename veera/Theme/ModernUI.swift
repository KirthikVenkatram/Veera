import SwiftUI

// Modern UI primitives layered on top of the heraldic baseline. These exist so the
// new look (depth, glass, hero typography, segmented sections) is centralized in
// one place — change here, the whole app shifts.

// MARK: - Gradients

extension Theme {

    /// Cooler, slightly warm parchment gradient used as the base fill for hero cards.
    /// Diagonal from top-leading so the light feels like it's coming from above-left.
    static let surfaceGradient = LinearGradient(
        colors: [
            Color(red: 0x1E/255, green: 0x18/255, blue: 0x10/255),
            Color(red: 0x12/255, green: 0x0E/255, blue: 0x09/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A vertical gold gradient with a subtle highlight band at the top — used on
    /// progress bars, segmented control selection, and emphasis fills.
    static let goldGradient = LinearGradient(
        colors: [
            Color(red: 0xE7/255, green: 0xC1/255, blue: 0x6A/255),
            Theme.gold,
            Color(red: 0xA8/255, green: 0x82/255, blue: 0x3B/255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// A soft top-down light overlay for cards. Mimics a polished surface catching
    /// light from above without pulling attention from the content.
    static let cardHighlight = LinearGradient(
        colors: [
            Color.white.opacity(0.05),
            Color.clear,
            Color.black.opacity(0.20)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Hairline gold border stroke gradient. Brighter on the top-leading edge,
    /// fading into shadow — reads as embossed metal rather than a flat outline.
    static let cardStroke = LinearGradient(
        colors: [Theme.gold.opacity(0.45), Theme.border.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Card surfaces

extension View {
    /// Modern glass card: liquid glass background + subtle gold highlight overlay
    /// + hairline embossed stroke. This is the new default for stationary content
    /// surfaces. Replaces `roundedCard()` for the modernized look.
    func glassCard(cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surfaceGradient)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.cardHighlight)
                    .allowsHitTesting(false)
            )
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 0.8)
            )
    }

    /// Heavier hero card. Same shape as glassCard but with a brighter gold edge —
    /// reserved for the page-topping summary card on each tab.
    func heroCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surfaceGradient)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Theme.gold.opacity(0.18), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
                    .allowsHitTesting(false)
            )
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.gold.opacity(0.7), Theme.gold.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Section header

/// A consistent header used above every section across tabs. Title is gold +
/// engraved; optional caption sits below in muted gold; optional trailing
/// accessory floats right (e.g. a "View All" affordance or value chip).
struct SectionLabel<Accessory: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(Fonts.label)
                    .tracking(2.5)
                    .foregroundStyle(Theme.gold)
                if let caption {
                    Text(caption)
                        .font(Fonts.micro)
                        .tracking(1)
                        .foregroundStyle(Theme.mutedGold)
                }
            }
            Spacer(minLength: 0)
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SectionLabel where Accessory == EmptyView {
    init(_ title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
        self.accessory = { EmptyView() }
    }
}

// MARK: - Metric tile

/// A small composable metric tile for grids. Optional icon + label up top,
/// big serif numeral, optional caption below.
struct MetricTile: View {
    let value: String
    let label: String
    var icon: String?
    var accent: Color = Theme.gold
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.85))
                }
                Text(label.uppercased())
                    .font(Fonts.micro)
                    .tracking(1.5)
                    .foregroundStyle(Theme.mutedGold)
            }
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let caption {
                Text(caption)
                    .font(Fonts.micro)
                    .tracking(1)
                    .foregroundStyle(Theme.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .glassCard()
    }
}

// MARK: - Segmented tab bar

/// A heraldic segmented control. Selected pill fills with the gold gradient and
/// reverses text to obsidian; idle pills stay parchment-on-glass.
struct SegmentedTabBar<Segment: Hashable & CaseIterable & RawRepresentable>: View
where Segment.RawValue == String {
    @Binding var selection: Segment
    let segments: [Segment]

    init(selection: Binding<Segment>, segments: [Segment]) {
        self._selection = selection
        self.segments = segments
    }

    init(selection: Binding<Segment>) where Segment.AllCases == [Segment] {
        self._selection = selection
        self.segments = Array(Segment.allCases)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments, id: \.self) { segment in
                let active = segment == selection
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                        selection = segment
                    }
                    HapticEngine.shared.tabChange()
                } label: {
                    Text(segment.rawValue.uppercased())
                        .font(Fonts.label)
                        .tracking(2)
                        .foregroundStyle(active ? Theme.obsidian : Theme.mutedGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            ZStack {
                                if active {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Theme.goldGradient)
                                        .shadow(color: Theme.gold.opacity(0.4), radius: 8, x: 0, y: 2)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Progress bar

/// A reusable gold progress bar with a glow under it. Used by the player card,
/// rank progress, etc.
struct GoldProgressBar: View {
    let progress: Double
    var height: CGFloat = 8
    var showsGlow: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.obsidian)
                    .overlay(
                        Capsule().stroke(Theme.border, lineWidth: 0.5)
                    )
                Capsule()
                    .fill(Theme.goldGradient)
                    .frame(width: max(height, geo.size.width * clamped))
                    .shadow(
                        color: showsGlow ? Theme.gold.opacity(0.5) : .clear,
                        radius: 6, x: 0, y: 0
                    )
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: clamped)
            }
        }
        .frame(height: height)
    }

    private var clamped: Double { min(max(progress, 0), 1) }
}
