import Foundation

// MARK: - Weather

/// The city's weather. It changes every three hours and is the same for every player at the same moment,
/// so it can become shared once there is a server. Each kind nudges one rule, to give each visit a twist.
public enum Weather: String, CaseIterable, Sendable {
    case sunny, cloudy, rain, snow

    public static let slotHours = 3

    /// The weather at `date`, from the date itself (no randomness on the device).
    public static func at(_ date: Date, calendar: Calendar = .current) -> Weather {
        let c = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let slot = (c.hour ?? 0) / slotHours
        var h = UInt64((c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)) &* 8 &+ UInt64(slot)
        h = (h ^ (h >> 33)) &* 0xff51afd7ed558ccd
        h = (h ^ (h >> 33)) &* 0xc4ceb9fe1a85ec53
        h ^= h >> 33
        let r = Double(h % 1000) / 1000
        let winter = [12, 1, 2].contains(c.month ?? 0)
        if winter { return r < 0.3 ? .snow : r < 0.55 ? .cloudy : r < 0.7 ? .rain : .sunny }
        return r < 0.45 ? .sunny : r < 0.75 ? .cloudy : .rain
    }

    /// When this weather slot ends.
    public static func nextChange(after date: Date, calendar: Calendar = .current) -> Date {
        let h = calendar.component(.hour, from: date)
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: (h / slotHours + 1) * slotHours, to: start) ?? date.addingTimeInterval(3 * 3600)
    }

    public var name: String {
        switch self {
        case .sunny: "Sunny"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .snow: "Snow"
        }
    }

    public var symbol: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.rain.fill"
        case .snow: "cloud.snow.fill"
        }
    }

    /// What this weather changes, in one line.
    public var effect: String {
        switch self {
        case .sunny: "Parks give an extra free roll."
        case .cloudy: "A calm day. Nothing special."
        case .rain: "Everyone shelters inside: cafés and shops pay double."
        case .snow: "Snowball fights: plaza duels pay double."
        }
    }
}

// MARK: - Holidays

/// A seasonal event. While it runs, the city is decorated, street pickups also give event tokens,
/// and collecting enough unlocks a free skin. Its pack (a real-money purchase) adds a skin,
/// decorations on your own block and rolls.
public struct Holiday: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    /// Inclusive month/day window. A window may run across New Year.
    public var start: (month: Int, day: Int)
    public var end: (month: Int, day: Int)
    public var token: String
    public var tokenSymbol: String
    public var goal: Int
    public var rewardSkin: String
    public var packSkin: String
    public var packPrice: String
    public var packRolls: Int

    public static func == (a: Holiday, b: Holiday) -> Bool { a.id == b.id }

    public static let all: [Holiday] = [
        Holiday(id: "halloween", name: "Halloween", start: (10, 20), end: (11, 2), token: "candy", tokenSymbol: "🍬",
                goal: 25, rewardSkin: "pumpkin", packSkin: "witch", packPrice: "$1.99", packRolls: 20),
        Holiday(id: "winter", name: "Winter Lights", start: (12, 10), end: (1, 6), token: "snowflake", tokenSymbol: "❄️",
                goal: 25, rewardSkin: "snowman", packSkin: "santa", packPrice: "$1.99", packRolls: 20),
        Holiday(id: "spring", name: "Cherry Blossom", start: (3, 20), end: (4, 15), token: "petal", tokenSymbol: "🌸",
                goal: 25, rewardSkin: "blossom", packSkin: "sakura", packPrice: "$1.99", packRolls: 20),
    ]

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day], from: date)
        let v = (c.month ?? 0) * 100 + (c.day ?? 0)
        let a = start.month * 100 + start.day, b = end.month * 100 + end.day
        return a <= b ? (a...b).contains(v) : (v >= a || v <= b)
    }

    /// The holiday running at `date`, if any.
    public static func active(at date: Date, calendar: Calendar = .current) -> Holiday? {
        all.first { $0.contains(date, calendar: calendar) }
    }

    /// Whole days left, counting today.
    public func daysLeft(from date: Date, calendar: Calendar = .current) -> Int {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let endYear = (end.month < m) ? y + 1 : y
        guard let last = calendar.date(from: DateComponents(year: endYear, month: end.month, day: end.day)) else { return 0 }
        return max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: last).day ?? 0) + 1)
    }
}

// MARK: - Land value

extension CityMap {
    /// What a block is worth in coins: its location plus what stands on it.
    /// Location counts streets on the block, the bus line, closeness to the city centre and nearby monuments.
    public func plotValue(_ bi: Int) -> Int {
        let o = Self.blockOrigin(bi), B = Self.blockSize
        var streets = 0, buildings = 0.0, onBus = false
        for y in o.y..<(o.y + B) {
            for x in o.x..<(o.x + B) {
                let c = Cell(x, y), t = tiles[y][x]
                if t == .road { streets += 1; if isOnBusRoute(c) { onBus = true } }
                else if t.isBuilding { buildings += Double(t.cost) * levelFactor(at: c) * (t.isMonument ? 1 : 1.5) }
            }
        }
        let bx = bi % Self.blocksPerSide, by = bi / Self.blocksPerSide, mid = Self.blocksPerSide / 2
        let central = max(0, 3 - (abs(bx - mid) + abs(by - mid))) * 50
        var nearMonuments = 0
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = bx + dx, ny = by + dy
            guard (0..<Self.blocksPerSide).contains(nx), (0..<Self.blocksPerSide).contains(ny) else { continue }
            let n = ny * Self.blocksPerSide + nx, no = Self.blockOrigin(n)
            if (no.y..<(no.y + B)).contains(where: { y in tiles[y][no.x..<(no.x + B)].contains { $0.isMonument } }) { nearMonuments += 1 }
        }
        let location = 120 + streets * 6 + (onBus ? 100 : 0) + central + nearMonuments * 60
        return location + Int(buildings.rounded())
    }
}
