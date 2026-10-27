import SwiftUI
import Observation
import UIKit

/// A short message shown at the top of the screen.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var detail: String?
}

struct ForkChoice: Identifiable, Equatable {
    var id: Int
    var dir: Dir
    var label: String
}

struct DuelState: Equatable {
    var block: Int
    var opponent: String
    var city: String
    var you: Int?
    var them: Int?
    var result: Rules.DuelResult?
}

/// A simulated other player rolling around the city.
struct Ghost: Identifiable {
    let id: Int
    var block: Int
    var name: String
    var city: String
    var color: UInt32
    var cell: Cell
    var heading: Dir
    var nextTurn: Date
    var busy = false
}

private struct SaveData: Codable {
    var player: PlayerState
    var ownership: [Ownership]
}

/// Owns the game state and runs turns. The 3D scene is driven through `scene`.
@MainActor
@Observable
final class GameModel {
    var map = CityMap.example()
    var player = PlayerState()
    var needs: Needs
    var now = Date()

    var isBusy = false
    var toast: Toast?
    var rolledValue: Int?
    var forkChoices: [ForkChoice] = []
    var duel: DuelState?
    var saleOffer: Int?
    var feed: [String] = []

    var showShop = false
    var showMissions = false

    @ObservationIgnored weak var scene: CityScene?
    @ObservationIgnored private var forkContinuation: CheckedContinuation<Int, Never>?
    @ObservationIgnored private var duelContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var saleContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private(set) var ghosts: [Ghost] = []
    @ObservationIgnored private(set) var pickups: Set<Cell> = []
    @ObservationIgnored private var ticker: Task<Void, Never>?
    private let haptic: UIImpactFeedbackGenerator
    private static let saveKey = "giro.save.v1"

    init() {
        haptic = UIImpactFeedbackGenerator(style: .light)
        let m = CityMap.example()
        needs = Needs.of(m)
        load()
        needs = Needs.of(map)
        let roads = map.roadCells
        let ghostSeeds: [(Int, UInt32)] = [(0, 0xE5533D), (1, 0x4A90D9), (2, 0x5DBB63), (5, 0xF28C28), (8, 0xE58BA8), (21, 0x6B4A9E)]
        ghosts = ghostSeeds.enumerated().map { i, s in
            let start = roads[(i * 53 + 17) % roads.count]
            return Ghost(id: i, block: s.0, name: map.owners[s.0].name, city: map.owners[s.0].city, color: s.1,
                         cell: start, heading: .east, nextTurn: Date().addingTimeInterval(1.5 + Double(i) * 0.9))
        }
        for _ in 0..<26 { dropCoin() }
    }

    // MARK: Lifecycle

    func start() {
        guard ticker == nil else { return }
        player.regenerate(now: Date())
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.tick()
            }
        }
        showToast("You're the yellow pawn, on your own block.", "Tap ROLL to drive into the city.", seconds: 4)
    }

    private func tick() {
        now = Date()
        if player.regenerate(now: now) > 0 { save() }
        for g in ghosts where !g.busy && now >= g.nextTurn {
            Task { await ghostTurn(g.id) }
        }
    }

    // MARK: Rolling

    var canRoll: Bool { !isBusy && player.rolls >= player.multiplier }

    func roll(forced: Int? = nil) async {
        guard !isBusy, let scene else { return }
        guard player.spendRoll() else {
            showToast("Out of rolls", "A free roll arrives every \(Int(GameConfig.rollRegenSeconds)) seconds, or get more in the shop.")
            return
        }
        isBusy = true
        haptic.impactOccurred()
        let v = forced ?? Int.random(in: 1...6)
        scene.followPawn = true
        await scene.throwDie(showing: v)
        showRolled(v)
        for _ in 0..<v {
            let opts = map.options(at: player.position, heading: player.heading)
            guard !opts.isEmpty else { break }
            var d = opts[0]
            if opts.count > 1 {
                let pick = await chooseFork(opts)
                d = opts[pick]
            }
            let next = player.position.moved(d)
            await scene.hopPawn(to: next)
            haptic.impactOccurred(intensity: 0.5)
            player.position = next
            player.heading = d
            enter(next)
        }
        await land()
        if player.rolls < player.multiplier { player.multiplier = 1 }
        isBusy = false
        save()
    }

    func cycleMultiplier() { player.cycleMultiplier() }

    private func showRolled(_ v: Int) {
        rolledValue = v
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            if self?.rolledValue == v { self?.rolledValue = nil }
        }
    }

    private func chooseFork(_ opts: [Dir]) async -> Int {
        forkChoices = opts.enumerated().map { i, d in
            ForkChoice(id: i, dir: d, label: map.destinationLabel(from: player.position, toward: d, stamps: player.stamps))
        }
        scene?.showForkArrows(at: player.position, dirs: opts)
        let i = await withCheckedContinuation { forkContinuation = $0 }
        forkChoices = []
        scene?.clearForkArrows()
        return i
    }

    func pickFork(_ index: Int) {
        guard let c = forkContinuation else { return }
        forkContinuation = nil
        c.resume(returning: index)
    }

    /// Called for every square the pawn enters (coins on the street, passport stamps).
    private func enter(_ c: Cell) {
        let m = player.multiplier
        if pickups.remove(c) != nil {
            scene?.removeCoin(at: c)
            gain(GameConfig.streetCoinCoins * m, at: c)
            player.advance(.pickups)
            dropCoin()
        }
        let bi = map.block(of: c)
        if map.ownership[bi] == .other && !player.stamps.contains(bi) {
            player.stamps.insert(bi)
            player.advance(.stamps)
            gain(GameConfig.stampCoins * m, at: nil)
            showToast("New stamp: \(map.owners[bi].city)", "\(map.owners[bi].name)'s block · +\(GameConfig.stampCoins * m) coins", seconds: 1.8)
        }
    }

    private func land() async {
        let c = player.position
        switch Rules.landing(on: c, in: map, multiplier: player.multiplier) {
        case .quiet:
            showToast("A quiet corner. Nothing happens.")
        case .home:
            player.rolls += 1
            scene?.pop(text: "+1 roll", at: c, color: Theme.youHex)
            showToast("Home block: +1 roll")
        case .forSale(let b):
            await offerSale(b)
        case .coins(let amount, let place, let b):
            gain(amount, at: c)
            let o = map.owners[b]
            let what = place == .cafe ? "Coffee at \(o.name)'s café" : place == .office ? "Payday at \(o.name)'s office"
                : place == .school ? "Tutoring at \(o.name)'s school" : "Shopping at \(o.name)'s shop"
            showToast("\(what) in \(o.city)", "+\(amount) coins")
        case .freeRoll(let r, let b):
            player.rolls += r
            scene?.pop(text: "+\(r) roll\(r > 1 ? "s" : "")", at: c, color: 0x5DBB63)
            showToast("A walk in \(map.owners[b].name)'s park", "Free roll: +\(r)")
        case .duel(let b):
            await runDuel(b)
        case .bus:
            await busRide()
        case .neighbours(let amount, let b):
            gain(amount, at: c)
            showToast("\(map.owners[b].name)'s neighbours wave hello", "+\(amount) coins")
        }
    }

    private func gain(_ n: Int, at c: Cell?) {
        player.coins += n
        if let c { scene?.pop(text: "+\(n) ¢", at: c, color: 0xE0A100) }
    }

    // MARK: Bus

    private func busRide() async {
        guard let path = Rules.busRide(from: player.position, in: map), let scene else {
            gain(2 * player.multiplier, at: player.position)
            showToast("Bus stop, but no line here yet.", "+\(2 * player.multiplier) coins")
            return
        }
        showToast("All aboard: riding to the next stop")
        player.advance(.bus)
        player.busRides += 1
        await scene.ridePawn(along: path)
        var prev = player.position
        for c in path {
            player.heading = Dir(c.x - prev.x, c.y - prev.y)
            prev = c
            player.position = c
            enter(c)
        }
        if let f = map.frontage(of: player.position) {
            let who = map.ownership[f.block] == .mine ? "your block" : "\(map.owners[f.block].name)'s block in \(map.owners[f.block].city)"
            showToast("You got off next to \(who).")
        }
    }

    // MARK: Duel

    private func runDuel(_ b: Int) async {
        duel = DuelState(block: b, opponent: map.owners[b].name, city: map.owners[b].city)
        await withCheckedContinuation { duelContinuation = $0 }
        duel = nil
    }

    func rollDuel() {
        guard var d = duel, d.result == nil else { return }
        let a = Int.random(in: 1...6), b = Int.random(in: 1...6)
        d.you = a; d.them = b
        let r = Rules.duel(you: a, them: b, multiplier: player.multiplier)
        d.result = r
        switch r {
        case .win(let n): gain(n, at: player.position); player.advance(.duel)
        case .tie(let n): gain(n, at: nil)
        case .lose: break
        }
        haptic.impactOccurred()
        duel = d
    }

    func finishDuel() {
        duelContinuation?.resume()
        duelContinuation = nil
    }

    // MARK: Land

    private func offerSale(_ b: Int) async {
        saleOffer = b
        await withCheckedContinuation { saleContinuation = $0 }
        saleOffer = nil
    }

    /// Tapping a FOR SALE sign in the city.
    func offerSaleFromSign(_ b: Int) async {
        guard !isBusy, map.ownership[b] == .forSale else { return }
        isBusy = true
        await offerSale(b)
        isBusy = false
    }

    func answerSale(buy: Bool) {
        if buy, let b = saleOffer { self.buy(b) }
        saleContinuation?.resume()
        saleContinuation = nil
    }

    func buy(_ b: Int) {
        guard map.ownership[b] == .forSale, let price = map.plotPrices[b], player.coins >= price else { return }
        player.coins -= price
        map.ownership[b] = .mine
        map.owners[b] = BlockOwner(name: "You", city: "your city")
        needs = Needs.of(map)
        scene?.rebuildBlock(b, in: map)
        showToast("You bought plot \(b + 1)", b == 11 ? "The bus line runs along it." : nil, seconds: 3)
        save()
    }

    // MARK: Ghost players

    private func ghostTurn(_ id: Int) async {
        guard let i = ghosts.firstIndex(where: { $0.id == id }), !ghosts[i].busy, let scene else { return }
        ghosts[i].busy = true
        let v = Int.random(in: 1...6)
        for _ in 0..<v {
            let g = ghosts[i]
            let o = map.options(at: g.cell, heading: g.heading)
            guard let d = o.randomElement() else { break }
            let next = g.cell.moved(d)
            await scene.hopGhost(id, to: next)
            ghosts[i].cell = next
            ghosts[i].heading = d
        }
        if let f = map.frontage(of: ghosts[i].cell), map.ownership[f.block] == .mine, f.tile.isVisitable {
            let pay = max(1, Int((Double(f.tile.visitValue) * 4 * needs.visitMultiplier).rounded()))
            player.coins += pay
            player.earnedToday += pay
            player.visitsToday += 1
            let g = ghosts[i]
            scene.pop(text: "+\(pay) ¢", at: f.cell, color: 0xE0A100)
            feed.insert("\(g.name) from \(g.city) stopped at your \(f.tile.noun) +\(pay) ¢", at: 0)
            if feed.count > 6 { feed.removeLast() }
            if !isBusy { showToast("\(g.name) from \(g.city) stopped at your \(f.tile.noun)", "+\(pay) coins for you", seconds: 2.2) }
            save()
        }
        ghosts[i].busy = false
        ghosts[i].nextTurn = Date().addingTimeInterval(2.2 + Double.random(in: 0...3))
    }

    // MARK: Coins on the street

    private func dropCoin() {
        let roads = map.roadCells
        for _ in 0..<20 {
            guard let c = roads.randomElement() else { return }
            if pickups.contains(c) || map.isIntersection(c) || c == player.position { continue }
            pickups.insert(c)
            scene?.addCoin(at: c)
            return
        }
    }

    // MARK: Shop and missions

    func purchase(_ item: ShopItem) {
        var n = item.rolls
        if case .coins(let price) = item.price {
            guard player.coins >= price else { return }
            player.coins -= price
        }
        if item.isCrate {
            n = ShopItem.openCrate(roll: Double.random(in: 0..<1))
            showToast("Mystery crate: \(n) rolls")
        } else if case .money = item.price {
            showToast("Demo purchase: +\(n) rolls", "Nothing was charged.")
        } else {
            showToast("+\(n) rolls")
        }
        if item.isPass { player.goldenPawn = true; scene?.setGoldenPawn(true) }
        player.rolls += n
        save()
    }

    func claim(_ m: Mission) {
        if player.claim(m) { showToast("Mission done: +\(m.rewardRolls) rolls"); save() }
    }

    // MARK: Toasts

    func showToast(_ title: String, _ detail: String? = nil, seconds: Double = 2.6) {
        let t = Toast(title: title, detail: detail)
        toast = t
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            if self?.toast?.id == t.id { self?.toast = nil }
        }
    }

    // MARK: Persistence

    private func save() {
        let d = SaveData(player: player, ownership: map.ownership)
        if let data = try? JSONEncoder().encode(d) { UserDefaults.standard.set(data, forKey: Self.saveKey) }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let d = try? JSONDecoder().decode(SaveData.self, from: data),
              d.ownership.count == map.ownership.count else { return }
        player = d.player
        map.ownership = d.ownership
        for b in map.ownership.indices where map.ownership[b] == .mine { map.owners[b] = BlockOwner(name: "You", city: "your city") }
        if !map.isRoad(player.position) { player.position = Cell(12, 14); player.heading = .east }
    }

    func resetProgress() {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
        player = PlayerState()
        map = CityMap.example()
        needs = Needs.of(map)
        scene?.rebuildAll(map: map, pawnAt: player.position)
    }
}
