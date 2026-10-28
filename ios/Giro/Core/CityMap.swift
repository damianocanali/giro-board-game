import Foundation

// MARK: - Basic types

/// A square on the 30x30 city grid. x grows east, y grows south (same as the web prototype).
public struct Cell: Hashable, Codable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int
    public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    public func moved(_ d: Dir) -> Cell { Cell(x + d.dx, y + d.dy) }
    public var description: String { "(\(x),\(y))" }
}

public struct Dir: Hashable, Codable, Sendable {
    public var dx: Int
    public var dy: Int
    public init(_ dx: Int, _ dy: Int) { self.dx = dx; self.dy = dy }
    public static let east = Dir(1, 0), south = Dir(0, 1), west = Dir(-1, 0), north = Dir(0, -1)
    public var reversed: Dir { Dir(-dx, -dy) }
    /// Order used when listing movement options (matches the prototype).
    public static let optionOrder: [Dir] = [.east, .south, .west, .north]
    /// Order used when scanning neighbours for frontage (matches the prototype).
    public static let frontageOrder: [Dir] = [.south, .east, .north, .west]
}

/// What occupies a grid square.
public enum Tile: Character, Codable, CaseIterable, Sendable {
    case road = "="
    case house = "h"
    case apartments = "a"
    case shop = "s"
    case cafe = "c"
    case office = "o"
    case school = "k"
    case park = "p"
    case plaza = "f"
    case busStop = "b"
    case empty = "."
    // Monuments: one of each per player, only in their own city.
    case liberty = "L", empireState = "E"
    case colosseum = "C", stPeters = "D"
    case eiffel = "F", arc = "A"
    case bigBen = "B", londonEye = "O"
    case tokyoTower = "T", pagoda = "G"
    case pyramids = "P", sphinx = "X"

    /// Cities you can call home, and the monuments each one can build.
    public static let homeCities: [(city: String, monuments: [Tile])] = [
        ("New York", [.liberty, .empireState]),
        ("Roma", [.colosseum, .stPeters]),
        ("Paris", [.eiffel, .arc]),
        ("London", [.bigBen, .londonEye]),
        ("Tokyo", [.tokyoTower, .pagoda]),
        ("Cairo", [.pyramids, .sphinx]),
    ]

    /// The monuments a city can build. Brooklyn counts as New York.
    public static func monuments(in city: String?) -> [Tile] {
        let c = city == "Brooklyn" ? "New York" : city
        return homeCities.first { $0.city == c }?.monuments ?? []
    }

    public var isMonument: Bool { Tile.homeCities.contains { $0.monuments.contains(self) } }

    /// Highest level a building can be upgraded to.
    public static let maxLevel = 3
    public var canUpgrade: Bool { isBuilding && !isMonument }
    /// Coins to go from `level - 1` to `level`.
    public func upgradeCost(to level: Int) -> Int { cost * (level == 2 ? 3 : 6) }

    public var name: String {
        switch self {
        case .road: "Street"
        case .house: "House"
        case .apartments: "Apartments"
        case .shop: "Shop"
        case .cafe: "Café"
        case .office: "Office"
        case .school: "School"
        case .park: "Park"
        case .plaza: "Plaza"
        case .busStop: "Bus stop"
        case .empty: "Remove"
        case .liberty: "Statue of Liberty"
        case .empireState: "Empire State Building"
        case .colosseum: "Colosseum"
        case .stPeters: "St Peter's Basilica"
        case .eiffel: "Eiffel Tower"
        case .arc: "Arc de Triomphe"
        case .bigBen: "Big Ben"
        case .londonEye: "London Eye"
        case .tokyoTower: "Tokyo Tower"
        case .pagoda: "Five-storey Pagoda"
        case .pyramids: "Pyramids of Giza"
        case .sphinx: "Great Sphinx"
        }
    }
    /// Lower-case noun used in sentences ("stopped at your café").
    public var noun: String { isMonument ? name : name.lowercased() }
    public var cost: Int {
        switch self {
        case .road: 5
        case .house: 20
        case .apartments: 60
        case .shop: 40
        case .cafe: 35
        case .office: 80
        case .school: 70
        case .park: 15
        case .plaza: 25
        case .busStop: 30
        case .empty: 0
        case .liberty, .eiffel, .colosseum, .pyramids: 1500
        case .empireState, .bigBen, .tokyoTower: 1300
        case .stPeters, .arc, .londonEye, .pagoda, .sphinx: 1000
        }
    }
    public var residents: Int { switch self { case .house: 4; case .apartments: 12; default: 0 } }
    public var jobs: Int { switch self { case .shop: 3; case .cafe: 2; case .office: 15; case .school: 4; default: isMonument ? 8 : 0 } }
    public var shopping: Int { switch self { case .shop: 10; case .cafe: 8; default: isMonument ? 10 : 0 } }
    public var green: Int { switch self { case .park: 12; case .plaza: 6; default: isMonument ? 10 : 0 } }
    /// Multiplier used when someone visits this place.
    public var visitValue: Int {
        switch self {
        case .shop: 3
        case .cafe, .office, .plaza: 2
        default: isMonument ? 6 : 1
        }
    }
    /// Places other players can "stop at" and pay you for.
    public var isVisitable: Bool { isMonument || [.shop, .cafe, .office, .school, .park, .plaza].contains(self) }
    public var isBuilding: Bool { self != .road && self != .empty }
}

public enum Ownership: String, Codable, Sendable { case mine, other, forSale }

public struct BlockOwner: Codable, Hashable, Sendable {
    public var name: String
    public var city: String
}

/// Deterministic Park–Miller generator, identical to the prototype's `rng(seed)`.
public struct ParkMiller: Sendable {
    private var s: Int
    public init(seed: Int) { s = seed }
    public mutating func next() -> Double {
        s = (s * 16807) % 2147483647
        return Double(s) / 2147483647
    }
    public mutating func int(below n: Int) -> Int { min(n - 1, Int(next() * Double(n))) }
}

// MARK: - City map

/// The shared city. 5x5 blocks of 6x6 squares; every street square is a board square.
public struct CityMap: Codable, Sendable {
    public static let blockSize = 6
    public static let blocksPerSide = 5
    public static let size = blockSize * blocksPerSide // 30
    public static let homeBlock = 12

    /// Street offsets inside each row/column of blocks (same as prototype HO / VO).
    static let horizontalOffsets = [2, 3, 2, 3, 2]
    static let verticalOffsets = [3, 2, 2, 3, 2]

    public var tiles: [[Tile]] // [y][x]
    /// Upgrade level of your buildings (missing means level 1).
    public var levels: [Cell: Int] = [:]
    public func level(at c: Cell) -> Int { levels[c] ?? 1 }
    /// How much an upgraded building adds compared with level 1.
    public func levelFactor(at c: Cell) -> Double { 1 + 0.5 * Double(level(at: c) - 1) }

    public enum UpgradeResult: Equatable, Sendable {
        case upgraded(level: Int, cost: Int)
        case notYourBuilding
        case maxed
        case tooExpensive(cost: Int)
    }

    /// Raise one of your buildings a level, paying from `coins`.
    public mutating func upgrade(_ c: Cell, coins: inout Int) -> UpgradeResult {
        guard let t = tile(c), t.canUpgrade, ownership(of: c) == .mine else { return .notYourBuilding }
        let next = level(at: c) + 1
        guard next <= Tile.maxLevel else { return .maxed }
        let cost = t.upgradeCost(to: next)
        guard coins >= cost else { return .tooExpensive(cost: cost) }
        coins -= cost
        levels[c] = next
        return .upgraded(level: next, cost: cost)
    }
    public var ownership: [Ownership]
    public var owners: [BlockOwner]
    public let plotPrices: [Int: Int]
    public let busRoute: [Cell]

    public static let defaultOwners: [BlockOwner] = [
        ("Giulia", "Roma"), ("Kenji", "Osaka"), ("Ana", "Lisboa"), ("Amara", "Lagos"), ("Lucas", "São Paulo"),
        ("Leila", "Marrakech"), ("Maya", "Brooklyn"), ("Sven", "Oslo"), ("Hiro", "Tokyo"), ("Noor", "Dubai"),
        ("Chloé", "Paris"), ("", ""), ("You", "your city"), ("", ""), ("Tunde", "Accra"),
        ("Ines", "Madrid"), ("Omar", "Cairo"), ("", ""), ("Priya", "Mumbai"), ("Mateo", "Bogotá"),
        ("Ewa", "Kraków"), ("Liam", "Dublin"), ("Yuki", "Sapporo"), ("Zara", "London"), ("Felix", "Berlin"),
    ].map { BlockOwner(name: $0.0, city: $0.1) }

    public static let defaultPlotPrices: [Int: Int] = [11: 300, 13: 250, 17: 200]

    /// Builds the example city exactly like the web prototype (seeded, deterministic).
    public static func example() -> CityMap {
        let n = size
        var owners = defaultOwners
        let ownership: [Ownership] = owners.indices.map { i in
            if defaultPlotPrices[i] != nil { return .forSale }
            return i == homeBlock ? .mine : .other
        }
        var t = Array(repeating: Array(repeating: Tile.empty, count: n), count: n)
        for by in 0..<blocksPerSide {
            let y = by * blockSize + horizontalOffsets[by]
            for x in 0..<n { t[y][x] = .road }
        }
        for bx in 0..<blocksPerSide {
            let x = bx * blockSize + verticalOffsets[bx]
            for y in 0..<n { t[y][x] = .road }
        }
        func road(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < n && y < n && t[y][x] == .road }
        func nearRoad(_ x: Int, _ y: Int) -> Bool { road(x + 1, y) || road(x - 1, y) || road(x, y + 1) || road(x, y - 1) }
        let flavours = ["hhscphoa", "ohoacsk", "hhaspcf", "ssccohp", "hhhakpsf", "oooacsf"].map { Array($0) }
        var r = ParkMiller(seed: 7)
        for y in 0..<n {
            for x in 0..<n {
                let bi = blockIndex(x, y)
                // Same short-circuit order as the prototype so the random sequence matches.
                if ownership[bi] != .other || t[y][x] != .empty || !nearRoad(x, y) || r.next() < 0.12 { continue }
                let fl = flavours[bi % flavours.count]
                t[y][x] = Tile(rawValue: fl[Int(r.next() * Double(fl.count))])!
            }
        }
        let home = [".h=s..", "hp=hcs", "======", "hh=p=o", ".a===h", ".f=hp."]
        let hx = (homeBlock % blocksPerSide) * blockSize, hy = (homeBlock / blocksPerSide) * blockSize
        for (dy, row) in home.enumerated() {
            for (dx, ch) in row.enumerated() { t[hy + dy][hx + dx] = Tile(rawValue: ch)! }
        }
        var route: [Cell] = []
        for x in 8...21 { route.append(Cell(x, 9)) }
        for y in 10...21 { route.append(Cell(21, y)) }
        for x in stride(from: 20, through: 8, by: -1) { route.append(Cell(x, 21)) }
        for y in stride(from: 20, through: 10, by: -1) { route.append(Cell(8, y)) }
        for (x, y) in [(10, 8), (15, 22), (22, 18), (20, 10)] where ownership[blockIndex(x, y)] == .other && t[y][x] != .road {
            t[y][x] = .busStop
        }
        // Players from monument cities have their city's first monument on their block.
        for (bi, o) in owners.enumerated() where ownership[bi] == .other {
            guard let m = Tile.monuments(in: o.city).first else { continue }
            let ox = (bi % blocksPerSide) * blockSize, oy = (bi / blocksPerSide) * blockSize
            spot: for y in oy..<(oy + blockSize) {
                for x in ox..<(ox + blockSize) where t[y][x].isBuilding && t[y][x] != .busStop && nearRoad(x, y) {
                    t[y][x] = m
                    break spot
                }
            }
        }
        for (i, _) in owners.enumerated() where ownership[i] == .forSale { owners[i] = BlockOwner(name: "", city: "") }
        return CityMap(tiles: t, ownership: ownership, owners: owners, plotPrices: defaultPlotPrices, busRoute: route)
    }

    // MARK: Geometry helpers

    public static func blockIndex(_ x: Int, _ y: Int) -> Int { (y / blockSize) * blocksPerSide + (x / blockSize) }
    public func block(of c: Cell) -> Int { Self.blockIndex(c.x, c.y) }
    public static func blockOrigin(_ bi: Int) -> Cell { Cell((bi % blocksPerSide) * blockSize, (bi / blocksPerSide) * blockSize) }
    public func inBounds(_ c: Cell) -> Bool { c.x >= 0 && c.y >= 0 && c.x < Self.size && c.y < Self.size }
    public func tile(_ c: Cell) -> Tile? { inBounds(c) ? tiles[c.y][c.x] : nil }
    public func isRoad(_ c: Cell) -> Bool { tile(c) == .road }
    public func isIntersection(_ c: Cell) -> Bool {
        isRoad(c) && (isRoad(c.moved(.west)) || isRoad(c.moved(.east))) && (isRoad(c.moved(.north)) || isRoad(c.moved(.south)))
    }
    public func ownership(of c: Cell) -> Ownership { ownership[block(of: c)] }
    public var roadCells: [Cell] {
        var out: [Cell] = []
        for y in 0..<Self.size { for x in 0..<Self.size where tiles[y][x] == .road { out.append(Cell(x, y)) } }
        return out
    }
    public var myBlocks: [Int] { ownership.indices.filter { ownership[$0] == .mine } }
    public func ownerLabel(_ bi: Int) -> String {
        switch ownership[bi] {
        case .mine: "Your block"
        case .forSale: "Plot \(bi + 1) (for sale)"
        case .other: "\(owners[bi].name) · \(owners[bi].city)"
        }
    }

    // MARK: Board rules

    /// The building a street square "faces". Your own buildings win, for-sale land next, then by priority.
    public struct Frontage: Equatable, Sendable {
        public var tile: Tile
        public var cell: Cell
        public var block: Int
        public var side: Dir
    }

    static let frontagePriority: [Tile] = Tile.allCases.filter(\.isMonument) + [.busStop, .plaza, .park, .cafe, .shop, .office, .school, .apartments, .house]

    public func frontage(of c: Cell) -> Frontage? {
        var best: Frontage? = nil
        var bestP = Int.max
        for d in Dir.frontageOrder {
            let n = c.moved(d)
            guard let t = tile(n), t != .road else { continue }
            let bi = block(of: n)
            var p = Self.frontagePriority.firstIndex(of: t) ?? 20
            if ownership[bi] == .mine { p -= 30 }
            if ownership[bi] == .forSale { p = 15 }
            if p < bestP { bestP = p; best = Frontage(tile: t, cell: n, block: bi, side: d) }
        }
        return best
    }

    public enum SquareKind: Equatable, Sendable {
        case home, forSale, shop, cafe, office, school, park, plaza, busStop, landmark
    }

    /// The board effect of a street square (nil = no marked effect).
    public func squareKind(_ f: Frontage?) -> SquareKind? {
        guard let f else { return nil }
        switch ownership[f.block] {
        case .mine: return .home
        case .forSale: return .forSale
        case .other:
            switch f.tile {
            case let t where t.isMonument: return .landmark
            case .busStop: return .busStop
            case .plaza: return .plaza
            case .park: return .park
            case .cafe: return .cafe
            case .shop: return .shop
            case .office: return .office
            case .school: return .school
            default: return nil
            }
        }
    }

    /// Where a pawn standing on `c`, facing `heading`, can go next. No U-turns unless it is a dead end.
    public func options(at c: Cell, heading: Dir) -> [Dir] {
        var o = Dir.optionOrder.filter { $0 != heading.reversed && isRoad(c.moved($0)) }
        if o.isEmpty && isRoad(c.moved(heading.reversed)) { o = [heading.reversed] }
        return o
    }

    /// Label for a fork option: whose block that road leads toward.
    public func destinationLabel(from c: Cell, toward d: Dir, stamps: Set<Int>) -> String {
        var p = c
        for _ in 0..<5 { let q = p.moved(d); if !isRoad(q) { break }; p = q }
        let tx = max(0, min(Self.size - 1, p.x + d.dx * 2)), ty = max(0, min(Self.size - 1, p.y + d.dy * 2))
        let bi = Self.blockIndex(tx, ty)
        switch ownership[bi] {
        case .mine: return "Your block"
        case .forSale: return "Plot \(bi + 1) (for sale)"
        case .other: return "\(owners[bi].name) · \(owners[bi].city)" + (stamps.contains(bi) ? "" : " · new stamp")
        }
    }

    public var busRouteIndex: [Cell: Int] { Dictionary(uniqueKeysWithValues: busRoute.enumerated().map { ($1, $0) }) }

    /// Route indices that have a bus stop next to them.
    public var busStopIndices: Set<Int> {
        var s = Set<Int>()
        for (i, c) in busRoute.enumerated() {
            for d in Dir.frontageOrder where tile(c.moved(d)) == .busStop { s.insert(i) }
        }
        return s
    }

    public func isOnBusRoute(_ c: Cell) -> Bool { busRoute.contains(c) }

    // MARK: Building rules (for build mode)

    public struct BuildIssues: Equatable, Sendable {
        public var brokenEdges: [Cell] = []
        public var unreachable: [Cell] = []
        /// Street squares on your land that the rest of the city can't drive to.
        public var disconnected: [Cell] = []
        public var isEmpty: Bool { brokenEdges.isEmpty && unreachable.isEmpty && disconnected.isEmpty }
        public var count: Int { brokenEdges.count + unreachable.count + disconnected.count }
    }

    /// Street squares reachable from the streets outside your land.
    public func connectedRoads() -> Set<Cell> {
        var seen = Set<Cell>(), stack: [Cell] = []
        for c in roadCells where ownership(of: c) != .mine { seen.insert(c); stack.append(c) }
        while let c = stack.popLast() {
            for d in Dir.optionOrder {
                let n = c.moved(d)
                if isRoad(n) && seen.insert(n).inserted { stack.append(n) }
            }
        }
        return seen
    }

    /// The street square closest to `c` (used when a street you stood on is built over).
    public func nearestRoad(to c: Cell) -> Cell? {
        roadCells.min { a, b in
            let da = (a.x - c.x) * (a.x - c.x) + (a.y - c.y) * (a.y - c.y)
            let db = (b.x - c.x) * (b.x - c.x) + (b.y - c.y) * (b.y - c.y)
            return da < db
        }
    }

    /// Streets on your border must continue the neighbour's streets; every building needs a street next to it;
    /// every street on your land must join the city's streets.
    public func buildIssues() -> BuildIssues {
        var out = BuildIssues()
        for bi in myBlocks {
            let o = Self.blockOrigin(bi), B = Self.blockSize
            func check(_ a: Cell, _ b: Cell) {
                guard inBounds(b), ownership[block(of: b)] != .mine else { return }
                if isRoad(a) != isRoad(b) { out.brokenEdges.append(a) }
            }
            for i in 0..<B {
                check(Cell(o.x + i, o.y), Cell(o.x + i, o.y - 1))
                check(Cell(o.x + i, o.y + B - 1), Cell(o.x + i, o.y + B))
                check(Cell(o.x, o.y + i), Cell(o.x - 1, o.y + i))
                check(Cell(o.x + B - 1, o.y + i), Cell(o.x + B, o.y + i))
            }
            for y in o.y..<(o.y + B) {
                for x in o.x..<(o.x + B) {
                    let c = Cell(x, y)
                    if tiles[y][x].isBuilding && !Dir.optionOrder.contains(where: { isRoad(c.moved($0)) }) { out.unreachable.append(c) }
                }
            }
        }
        let joined = connectedRoads()
        for bi in myBlocks {
            let o = Self.blockOrigin(bi)
            for y in o.y..<(o.y + Self.blockSize) {
                for x in o.x..<(o.x + Self.blockSize) where tiles[y][x] == .road && !joined.contains(Cell(x, y)) {
                    out.disconnected.append(Cell(x, y))
                }
            }
        }
        return out
    }
}
