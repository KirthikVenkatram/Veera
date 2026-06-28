import CoreHaptics
import UIKit

// Centralised haptic vocabulary. Views never touch UIFeedbackGenerator or
// CHHaptic directly — call `HapticEngine.shared.<verb>()` instead. Haptics in
// Veera *mean something*; they're reserved for completions, level/rank crossings,
// vow rites, and tab changes. Every other tap is silent on purpose.
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private static let toggleKey = "veera.haptics.enabled"

    private var coreEngine: CHHapticEngine?
    private let notification = UINotificationFeedbackGenerator()
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()

    enum QuestEvent {
        case complete
        case uncomplete
    }

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.toggleKey) as? Bool ?? true
    }

    private init() {
        notification.prepare()
        softImpact.prepare()
        selection.prepare()
        prepareCoreHaptics()
    }

    // MARK: - Public API

    func quest(_ event: QuestEvent) {
        guard isEnabled else { return }
        switch event {
        case .complete:
            notification.notificationOccurred(.success)
            notification.prepare()
        case .uncomplete:
            softImpact.impactOccurred(intensity: 0.6)
            softImpact.prepare()
        }
    }

    func tabChange() {
        guard isEnabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    func levelUp() {
        guard isEnabled else { return }
        playPattern(events: [
            tap(time: 0.00, intensity: 0.55, sharpness: 0.4),
            tap(time: 0.18, intensity: 0.75, sharpness: 0.6),
            tap(time: 0.36, intensity: 1.00, sharpness: 0.9)
        ])
    }

    func rankUp() {
        guard isEnabled else { return }
        let events: [CHHapticEvent] = (0..<5).map { index in
            let progress = Float(index) / 4.0
            return tap(
                time: TimeInterval(index) * 0.16,
                intensity: 0.55 + progress * 0.45,
                sharpness: 0.3 + progress * 0.65
            )
        }
        playPattern(events: events)
    }

    func vowSworn() {
        guard isEnabled else { return }
        let thud = CHHapticEvent(
            eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
            ], relativeTime: 0
        )
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
            ], relativeTime: 0.05, duration: 0.8
        )
        playPattern(events: [thud, rumble])
    }

    func vowBroken() {
        guard isEnabled else { return }
        playPattern(events: [
            tap(time: 0.0, intensity: 1.0, sharpness: 1.0),
            tap(time: 0.18, intensity: 1.0, sharpness: 1.0)
        ])
    }

    // MARK: - CHHaptic internals

    private func prepareCoreHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        coreEngine = try? CHHapticEngine()
        try? coreEngine?.start()
        coreEngine?.resetHandler = { [weak self] in try? self?.coreEngine?.start() }
        coreEngine?.stoppedHandler = { _ in }
    }

    private func tap(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private func playPattern(events: [CHHapticEvent]) {
        guard let coreEngine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try coreEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // CoreHaptics flake — drop silently.
        }
    }
}
