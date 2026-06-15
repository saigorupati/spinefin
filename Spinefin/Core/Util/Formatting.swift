import Foundation

enum TimeFormat {
    static let ticksPerSecond: Int64 = 10_000_000

    static func seconds(fromTicks ticks: Int64) -> Int { Int(ticks / ticksPerSecond) }

    /// Coarse duration like "9h 12m" / "47m".
    static func duration(ticks: Int64?) -> String {
        guard let ticks, ticks > 0 else { return "—" }
        let total = seconds(fromTicks: ticks)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return "\(m)m"
    }

    /// Clock like "42:18" or "1:42:18".
    static func clock(ticks: Int64?) -> String {
        guard let ticks, ticks > 0 else { return "0:00" }
        let total = seconds(fromTicks: ticks)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// Coarse "remaining" given total and elapsed fraction, e.g. "3h 24m left".
    static func remaining(totalTicks: Int64?, progress: Double) -> String? {
        guard let totalTicks, totalTicks > 0 else { return nil }
        let left = Int64(Double(totalTicks) * (1 - progress))
        return "\(duration(ticks: left)) left"
    }
}
