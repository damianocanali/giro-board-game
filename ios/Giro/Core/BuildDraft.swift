import Foundation

/// Changes you are making to your land in build mode. Nothing reaches the shared city until you open it.
public struct BuildDraft: Sendable {
    /// The city as everyone else sees it right now.
    public private(set) var base: CityMap
    /// The city with your changes painted in.
    public private(set) var map: CityMap

    public init(base: CityMap) {
        self.base = base
        self.map = base
    }

    /// Everything you can paint, in tray order. Remove comes first so it is easy to find.
    public static let tools: [Tile] = [.empty, .road, .house, .apartments, .shop, .cafe, .office, .school, .park, .plaza, .busStop]

    /// The tray for a player from `city`: the usual tools, then that city's monuments.
    public static func tools(city: String?) -> [Tile] { tools + Tile.monuments(in: city) }

    /// Earlier versions of the draft, for undo.
    private var history: [CityMap] = []
    public var canUndo: Bool { !history.isEmpty }

    public enum PaintResult: Equatable, Sendable {
        case painted
        case unchanged
        case notYourLand
        case busLine
        case tooExpensive(cost: Int)
        /// You already have this monument.
        case onlyOne
        /// This monument belongs to another city.
        case notYourCity
    }

    /// Squares that differ from the shared city.
    public var changedCells: [Cell] {
        var out: [Cell] = []
        for y in 0..<CityMap.size {
            for x in 0..<CityMap.size where map.tiles[y][x] != base.tiles[y][x] { out.append(Cell(x, y)) }
        }
        return out
    }

    public var hasChanges: Bool { map.tiles != base.tiles }

    /// What opening the draft costs: the price of every new thing you put down. Clearing is free,
    /// and putting a square back the way it was costs nothing.
    public var cost: Int { changedCells.reduce(0) { $0 + map.tiles[$1.y][$1.x].cost } }

    public var issues: CityMap.BuildIssues { map.buildIssues() }

    public var canOpen: Bool { hasChanges && issues.isEmpty }

    /// Paint `tile` on `cell` if you own it and can afford the whole draft with `coins`.
    @discardableResult
    public mutating func paint(_ cell: Cell, _ tile: Tile, coins: Int, city: String? = nil) -> PaintResult {
        guard map.inBounds(cell), map.ownership(of: cell) == .mine else { return .notYourLand }
        let old = map.tiles[cell.y][cell.x]
        guard old != tile else { return .unchanged }
        if tile.isMonument {
            guard Tile.monuments(in: city).contains(tile) else { return .notYourCity }
            if map.myBlocks.contains(where: { bi in
                let o = CityMap.blockOrigin(bi)
                return (o.y..<(o.y + CityMap.blockSize)).contains { y in map.tiles[y][o.x..<(o.x + CityMap.blockSize)].contains(tile) }
            }) { return .onlyOne }
        }
        // The bus line runs on fixed streets; removing one would strand the bus.
        if old == .road && map.isOnBusRoute(cell) { return .busLine }
        var next = map
        next.tiles[cell.y][cell.x] = tile
        let newCost = BuildDraft(base: base, map: next).cost
        if newCost > coins && newCost > cost { return .tooExpensive(cost: tile.cost) }
        history.append(map)
        map = next
        return .painted
    }

    /// Step back one change.
    public mutating func undo() {
        if let last = history.popLast() { map = last }
    }

    /// Take away only what can't stay, keeping everything else you painted.
    /// Changed squares with a problem go back to how they were; buildings that still have
    /// no street next to them are removed. Returns the squares that changed.
    @discardableResult
    public mutating func removeProblems() -> [Cell] {
        let before = map
        for _ in 0..<6 {
            let issues = map.buildIssues()
            if issues.isEmpty { break }
            var touched = false
            for c in issues.brokenEdges + issues.disconnected where map.tiles[c.y][c.x] != base.tiles[c.y][c.x] {
                map.tiles[c.y][c.x] = base.tiles[c.y][c.x]
                touched = true
            }
            if !touched {
                for c in issues.unreachable {
                    map.tiles[c.y][c.x] = .empty
                    touched = true
                }
            }
            if !touched { break }
        }
        var changed: [Cell] = []
        for y in 0..<CityMap.size { for x in 0..<CityMap.size where map.tiles[y][x] != before.tiles[y][x] { changed.append(Cell(x, y)) } }
        if !changed.isEmpty { history.append(before) }
        return changed
    }

    /// Upgrades happen straight away, so both the shared city and the draft take the new levels.
    public mutating func adoptLevels(_ levels: [Cell: Int]) {
        base.levels = levels
        map.levels = levels
        history = history.map { var m = $0; m.levels = levels; return m }
    }

    /// Land you buy while building is added to both the draft and the shared city.
    public mutating func adopt(ownership: [Ownership], owners: [BlockOwner]) {
        map.ownership = ownership
        map.owners = owners
    }

    private init(base: CityMap, map: CityMap) {
        self.base = base
        self.map = map
    }
}
