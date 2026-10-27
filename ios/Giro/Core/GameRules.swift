import Foundation

/// Tunable numbers in one place.
public enum GameConfig {
    public static let startingCoins = 500
    public static let startingRolls = 20
    public static let rollCap = 20
    /// Seconds per free roll. The web prototype used 20 s for testing; tune before release.
    public static let rollRegenSeconds: TimeInterval = 60
    public static let multipliers = [1, 2, 3, 5]

    public static let shopCoins = 8, officeCoins = 15, schoolCoins = 12, neighbourCoins = 3
    public static let duelWinCoins = 40, duelTieCoins = 10
    public static let stampCoins = 10, streetCoinCoins = 5
}

/// What happens when your pawn stops on a square.
public enum Landing: Equatable, Sendable {
    case quiet
    case home
    case forSale(block: Int)
    case coins(amount: Int, place: Tile, block: Int)
    case freeRoll(rolls: Int, block: Int)
    case duel(block: Int)
    case bus
    case neighbours(amount: Int, block: Int)
}

public enum Rules {
    /// Resolve a landing on street square `c` with bet multiplier `m`.
    public static func landing(on c: Cell, in map: CityMap, multiplier m: Int) -> Landing {
        guard let f = map.frontage(of: c) else { return .quiet }
        switch map.squareKind(f) {
        case .home: return .home
        case .forSale: return .forSale(block: f.block)
        case .shop: return .coins(amount: GameConfig.shopCoins * m, place: .shop, block: f.block)
        case .cafe: return .coins(amount: GameConfig.shopCoins * m, place: .cafe, block: f.block)
        case .office: return .coins(amount: GameConfig.officeCoins * m, place: .office, block: f.block)
        case .school: return .coins(amount: GameConfig.schoolCoins * m, place: .school, block: f.block)
        case .park: return .freeRoll(rolls: m, block: f.block)
        case .plaza: return .duel(block: f.block)
        case .busStop: return .bus
        case nil: return .neighbours(amount: GameConfig.neighbourCoins * m, block: f.block)
        }
    }

    public enum DuelResult: Equatable, Sendable { case win(Int), tie(Int), lose }
    public static func duel(you: Int, them: Int, multiplier m: Int) -> DuelResult {
        if you > them { return .win(GameConfig.duelWinCoins * m) }
        if you == them { return .tie(GameConfig.duelTieCoins * m) }
        return .lose
    }

    /// Walk `steps` squares, calling `choose` whenever there is more than one way to go.
    /// Returns the visited cells (not including the start) and the final heading.
    public static func walk(from start: Cell, heading: Dir, steps: Int, in map: CityMap, choose: ([Dir]) -> Int) -> (path: [Cell], heading: Dir) {
        var c = start, h = heading, path: [Cell] = []
        for _ in 0..<steps {
            let o = map.options(at: c, heading: h)
            guard !o.isEmpty else { break }
            let d = o.count > 1 ? o[max(0, min(o.count - 1, choose(o)))] : o[0]
            c = c.moved(d); h = d; path.append(c)
        }
        return (path, h)
    }

    /// Route cells from the stop at `index` to the next stop (exclusive of start, inclusive of end).
    public static func busRide(from c: Cell, in map: CityMap) -> [Cell]? {
        guard let i = map.busRouteIndex[c] else { return nil }
        let stops = map.busStopIndices, n = map.busRoute.count
        for k in 1..<n where stops.contains((i + k) % n) {
            return (1...k).map { map.busRoute[(i + $0) % n] }
        }
        return nil
    }
}

// MARK: - Neighbourhood needs

public struct Needs: Equatable, Sendable {
    public var residents: Int
    public var jobs: Double, shopping: Double, green: Double, transit: Double
    public var happiness: Double { (jobs + shopping + green + transit) / 4 }
    /// Multiplier applied to each visit you are paid for.
    public var visitMultiplier: Double { 0.5 + happiness }

    public static func of(_ map: CityMap) -> Needs {
        var res = 0, jobs = 0, shop = 0, green = 0, stops = 0, stopsOnLine = 0
        let route = Set(map.busRoute)
        for bi in map.myBlocks {
            let o = CityMap.blockOrigin(bi)
            for y in o.y..<(o.y + CityMap.blockSize) {
                for x in o.x..<(o.x + CityMap.blockSize) {
                    let t = map.tiles[y][x]
                    res += t.residents; jobs += t.jobs; shop += t.shopping; green += t.green
                    if t == .busStop {
                        stops += 1
                        if Dir.optionOrder.contains(where: { route.contains(Cell(x, y).moved($0)) }) { stopsOnLine += 1 }
                    }
                }
            }
        }
        let r = Double(max(1, res))
        return Needs(residents: res,
                     jobs: min(1, Double(jobs) / max(1, Double(res) * 0.6)),
                     shopping: min(1, Double(shop) / max(1, Double(res) * 1.2)),
                     green: min(1, Double(green) / r),
                     transit: stopsOnLine > 0 ? 1 : (stops > 0 ? 0.35 : 0))
    }
}

// MARK: - Missions and shop

public struct Mission: Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case stamps, bus, duel, pickups }
    public var id: Kind
    public var title: String
    public var goal: Int
    public var rewardRolls: Int
    public static let daily: [Mission] = [
        Mission(id: .stamps, title: "Collect 3 new passport stamps", goal: 3, rewardRolls: 6),
        Mission(id: .bus, title: "Ride a bus", goal: 1, rewardRolls: 5),
        Mission(id: .duel, title: "Win a plaza duel", goal: 1, rewardRolls: 8),
        Mission(id: .pickups, title: "Pick up 5 coins on the street", goal: 5, rewardRolls: 5),
    ]
}

public struct ShopItem: Identifiable, Sendable {
    public enum Price: Equatable, Sendable { case coins(Int), money(String) }
    public var id: String
    public var title: String
    public var detail: String
    public var price: Price
    public var rolls: Int
    public var isCrate = false
    public var isPass = false

    public static let catalog: [ShopItem] = [
        ShopItem(id: "rolls5", title: "5 rolls", detail: "Paid with coins", price: .coins(300), rolls: 5),
        ShopItem(id: "crate", title: "Mystery crate", detail: "3 to 25 rolls · odds below", price: .coins(150), rolls: 0, isCrate: true),
        ShopItem(id: "rolls25", title: "25 rolls", detail: "Starter pack", price: .money("$0.99"), rolls: 25),
        ShopItem(id: "rolls90", title: "90 rolls", detail: "Best value", price: .money("$2.99"), rolls: 90),
        ShopItem(id: "pass", title: "Giro pass", detail: "+30 rolls a day for 30 days, golden pawn", price: .money("$4.99"), rolls: 30, isPass: true),
    ]

    /// Published odds for the mystery crate (App Store guideline 3.1.1).
    public static let crateOdds: [(rolls: Int, chance: Double)] = [(3, 0.50), (6, 0.30), (12, 0.15), (25, 0.05)]
    public static var crateOddsText: String {
        "Mystery crate odds: " + crateOdds.map { "\($0.rolls) rolls \(Int($0.chance * 100))%" }.joined(separator: " · ")
    }
    public static func openCrate(roll r: Double) -> Int {
        var acc = 0.0
        for o in crateOdds { acc += o.chance; if r < acc { return o.rolls } }
        return crateOdds.last!.rolls
    }
}

// MARK: - Player state (persisted)

public struct PlayerState: Codable, Equatable, Sendable {
    public var coins: Int = GameConfig.startingCoins
    public var rolls: Int = GameConfig.startingRolls
    public var multiplier: Int = 1
    public var position = Cell(12, 14)
    public var heading = Dir.east
    public var stamps: Set<Int> = []
    public var progress: [Mission.Kind: Int] = [:]
    public var claimed: Set<Mission.Kind> = []
    public var goldenPawn = false
    public var lastRegen: Date = Date()
    public var visitsToday = 0
    public var earnedToday = 0
    public var busRides = 0

    public init() {}

    /// Add free rolls for time passed, up to the cap. Returns rolls added.
    @discardableResult
    public mutating func regenerate(now: Date) -> Int {
        guard rolls < GameConfig.rollCap else { lastRegen = now; return 0 }
        let n = Int(now.timeIntervalSince(lastRegen) / GameConfig.rollRegenSeconds)
        guard n > 0 else { return 0 }
        let add = min(n, GameConfig.rollCap - rolls)
        rolls += add
        lastRegen = lastRegen.addingTimeInterval(Double(n) * GameConfig.rollRegenSeconds)
        return add
    }

    public func secondsToNextRoll(now: Date) -> Int? {
        guard rolls < GameConfig.rollCap else { return nil }
        return max(0, Int(ceil(GameConfig.rollRegenSeconds - now.timeIntervalSince(lastRegen))))
    }

    /// Spend rolls for one throw. False if there are not enough.
    public mutating func spendRoll() -> Bool {
        guard rolls >= multiplier else { return false }
        rolls -= multiplier
        return true
    }

    public mutating func cycleMultiplier() {
        let l = GameConfig.multipliers
        let i = l.firstIndex(of: multiplier) ?? 0
        for k in 1...l.count {
            let m = l[(i + k) % l.count]
            if m <= max(1, rolls) { multiplier = m; return }
        }
    }

    public mutating func advance(_ k: Mission.Kind, by n: Int = 1) { progress[k, default: 0] += n }
    public func progress(of m: Mission) -> Int { min(m.goal, progress[m.id] ?? 0) }
    public func canClaim(_ m: Mission) -> Bool { !claimed.contains(m.id) && progress(of: m) >= m.goal }
    public mutating func claim(_ m: Mission) -> Bool {
        guard canClaim(m) else { return false }
        claimed.insert(m.id); rolls += m.rewardRolls
        return true
    }
}
