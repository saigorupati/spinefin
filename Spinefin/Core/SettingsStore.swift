import Foundation
import Observation

/// User playback preferences, persisted and applied by the player.
@MainActor
@Observable
final class SettingsStore {
    var defaultSpeed: Double { didSet { UserDefaults.standard.set(defaultSpeed, forKey: Keys.speed) } }
    var skipBackSeconds: Int { didSet { UserDefaults.standard.set(skipBackSeconds, forKey: Keys.back) } }
    var skipForwardSeconds: Int { didSet { UserDefaults.standard.set(skipForwardSeconds, forKey: Keys.forward) } }

    static let speedOptions: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    static let skipOptions: [Int] = [10, 15, 30, 45, 60]

    private enum Keys {
        static let speed = "spinefin.settings.speed"
        static let back = "spinefin.settings.skipBack"
        static let forward = "spinefin.settings.skipForward"
    }

    init() {
        let d = UserDefaults.standard
        defaultSpeed = d.object(forKey: Keys.speed) as? Double ?? 1.0
        skipBackSeconds = d.object(forKey: Keys.back) as? Int ?? 15
        skipForwardSeconds = d.object(forKey: Keys.forward) as? Int ?? 30
    }

    func speedLabel(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.1f×", value) : String(format: "%g×", value)
    }
}
