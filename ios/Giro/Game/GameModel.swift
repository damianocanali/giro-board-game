import AuthenticationServices
import SwiftUI
import Observation
import UIKit

/// A short message shown at the top of the screen.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var detail: String?
}

/// A new passport stamp, shown as a little ceremony.
struct StampEvent: Identifiable, Equatable {
    let id = UUID()
    var city: String
    var owner: String
    var coins: Int
    /// How many stamps you have now, counting this one.
    var number: Int
    var date = Date()
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
    /// What you built: each of your blocks as rows of tile characters. Optional so older saves still load.
    var myTiles: [Int: [String]]?
    /// Upgrade levels of your buildings, keyed "x,y".
    var myLevels: [String: Int]?
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
    /// The store you are inside, if any.
    var storeVisit: StoreVisit?
    /// Walking through a door: the screen fades to this message with a spinner.
    var doorFade: String?
    #if DEBUG
    @ObservationIgnored var debugStore: StoreVisit?
    #endif
    /// The weather right now (changes every three hours).
    var weather = Weather.at(Date())
    /// The holiday event running now, if any.
    var holiday = Holiday.active(at: Date())
    /// The title menu shown at launch.
    var showMenu = !ProcessInfo.processInfo.arguments.contains { ["-giroBuildDemo", "-giroRollDemo", "-giroMonumentDemo", "-giroStampDemo", "-giroStore"].contains($0) }
    var hasSave: Bool { UserDefaults.standard.data(forKey: Self.saveKey) != nil }
    var showMissions = false

    /// Non-nil while you are in build mode.
    var draft: BuildDraft?
    var buildTool: Tile = .house
    var isBuilding: Bool { draft != nil }

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
        for _ in 0..<14 { dropCoin() }
        music.isOn = musicOn
        sfx.isOn = soundOn
        GameCenter.shared.authenticate()
        if Account.shared.isSignedIn { Task { await syncAccount() } }
        #if DEBUG
        // `-giroSkin <id>` wears that skin, `-giroShowSkins YES` opens the skin picker (for screenshots).
        if let id = UserDefaults.standard.string(forKey: "giroSkin") {
            player.ownedSkins.insert(id); player.skinID = Skin.named(id).id
        }
        showSkins = UserDefaults.standard.bool(forKey: "giroShowSkins")
        // `-giroPet <item id>` walks a pet, `-giroStore <kind>` opens a store of that kind (for screenshots).
        if let id = UserDefaults.standard.string(forKey: "giroPet"), StoreItem.named(id) != nil {
            player.items.insert(id); player.pet = id
        }
        if let k = UserDefaults.standard.string(forKey: "giroStore").flatMap(StoreKind.init(rawValue:)) {
            debugStore = StoreVisit(cell: Cell(0, 0), kind: k, owner: k == .home ? "Your" : "Yuki's", city: "Sapporo")
        }
        // `-giroOutfit <n>` dresses you in a sample outfit.
        if UserDefaults.standard.object(forKey: "giroOutfit") != nil {
            player.outfit = .sample(UserDefaults.standard.integer(forKey: "giroOutfit"))
        }
        // `-giroWeather rain` (or sunny, cloudy, snow) fixes the weather.
        if let f = UserDefaults.standard.string(forKey: "giroWeather").flatMap(Weather.init(rawValue:)) { weather = f }
        #endif
    }

    // MARK: Lifecycle

    /// Leave the title menu and start playing.
    func play() {
        showMenu = false
        scene?.setShowcase(false)
        start()
    }

    func start() {
        guard ticker == nil, !showMenu else { return }
        if player.refillIfNewDay(now: Date()) > 0 { save() }
        #if DEBUG
        runBuildDemoIfRequested()
        if let v = debugStore { Task { try? await Task.sleep(for: .seconds(1)); await enter(v) } }
        #endif
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.tick()
            }
        }
        showToast("You're the yellow pawn, on your own block.", "Tap ROLL to drive into the city.", seconds: 4)
    }

    #if DEBUG
    /// Launch flags for screenshots and manual checks: `-giroRollDemo` rolls a 5, `-giroBuildDemo` opens build mode with a few
    /// changes painted, `-giroMonumentDemo` builds two New York monuments and upgrades a shop, `-giroStampDemo` shows a new stamp.
    func runBuildDemoIfRequested() {
        if ProcessInfo.processInfo.arguments.contains("-giroRollDemo") {
            Task { try? await Task.sleep(for: .seconds(1.5)); await roll(forced: 5) }
            return
        }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-giroStampDemo") {
            Task {
                try? await Task.sleep(for: .seconds(1))
                stampEvent = StampEvent(city: "Roma", owner: "Giulia", coins: 10, number: player.stamps.count + 1)
            }
            return
        }
        if args.contains("-giroMonumentDemo") {
            Task {
                try? await Task.sleep(for: .seconds(1))
                player.coins = max(player.coins, 6000)
                if player.homeCity == nil { chooseCity("New York") }
                enterBuild()
                buildTool = .liberty; paint(Cell(15, 13))
                buildTool = .empireState; paint(Cell(12, 15))
                try? await Task.sleep(for: .seconds(1))
                openToCity()
                try? await Task.sleep(for: .seconds(4))
                enterBuild()
                isUpgrading = true
                paint(Cell(17, 13)); paint(Cell(17, 13)); paint(Cell(16, 13))
            }
            return
        }
        guard args.contains("-giroBuildDemo") else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            enterBuild()
            buildTool = .cafe; paint(Cell(12, 12))
            buildTool = .road; paint(Cell(17, 17))
            buildTool = .shop; paint(Cell(12, 17))
        }
    }
    #endif

    private func tick() {
        now = Date()
        var w = Weather.at(now)
        #if DEBUG
        if let f = UserDefaults.standard.string(forKey: "giroWeather").flatMap(Weather.init(rawValue:)) { w = f }
        #endif
        if w != weather {
            weather = w
            scene?.setWeather(w)
            if !isBusy { showToast("Weather: \(w.name)", w.effect, seconds: 3) }
        }
        let h = Holiday.active(at: now)
        if h != holiday {
            holiday = h
            scene?.setHoliday(h, ownPack: h.map { player.packs.contains($0.id) } ?? false)
        }
        if player.refillIfNewDay(now: now) > 0 {
            save()
            showToast("A new day in the city", "Your \(GameConfig.dailyRolls) free rolls are back.", seconds: 4)
        }
        for g in ghosts where !g.busy && now >= g.nextTurn {
            Task { await ghostTurn(g.id) }
        }
    }

    // MARK: Rolling

    var canRoll: Bool { !isBusy && player.rolls > 0 }

    func roll(forced: Int? = nil) async {
        guard !isBusy, let scene else { return }
        guard player.spendRoll() else {
            showToast("Out of rolls for today", "New free rolls in \(Self.clock(player.secondsToRefill(now: Date()) ?? 0)). Missions and the shop give more.")
            return
        }
        isBusy = true
        haptic.impactOccurred()
        let v = forced ?? Int.random(in: 1...6)
        scene.followPawn = true
        sfx.play(.dice, volume: 0.6)
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
            await scene.walkPawn(to: next)
            haptic.impactOccurred(intensity: 0.5)
            player.position = next
            player.heading = d
            enter(next)
        }
        await land()
        isBusy = false
        save()
    }

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
        if pickups.remove(c) != nil {
            scene?.removeCoin(at: c)
            gain(GameConfig.streetCoinCoins, at: c)
            player.advance(.pickups)
            if let h = holiday {
                scene?.pop(text: "+1 \(h.tokenSymbol)", at: c.moved(player.heading), color: 0xFFE9A8)
                if player.collectToken(for: h) {
                    let skin = Skin.named(h.rewardSkin)
                    sfx.play(.achievement)
                    scene?.burst(at: c, count: 30, height: 2)
                    showToast("\(h.name) reward: the \(skin.name) skin!", "Wear it from Skins in the ⋯ menu.", seconds: 4)
                }
            }
            dropCoin()
        }
        let bi = map.block(of: c)
        if map.ownership[bi] == .other && !player.stamps.contains(bi) {
            player.stamps.insert(bi)
            player.advance(.stamps)
            gain(GameConfig.stampCoins, at: nil)
            let e = StampEvent(city: map.owners[bi].city, owner: map.owners[bi].name, coins: GameConfig.stampCoins, number: player.stamps.count)
            if stampEvent == nil { stampEvent = e } else { stampQueue.append(e) }
        }
    }

    private func land() async {
        let c = player.position
        switch Rules.landing(on: c, in: map, weather: weather) {
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
            let what = place.isMonument ? "Sightseeing at the \(place.name)" : place == .cafe ? "Coffee at \(o.name)'s café" : place == .office ? "Payday at \(o.name)'s office"
                : place == .school ? "Tutoring at \(o.name)'s school" : "Shopping at \(o.name)'s shop"
            showToast("\(what) in \(o.city)", "+\(amount) coins" + (weather == .rain && !place.isMonument ? " · rain bonus" : ""))
            if let v = store(facing: c) {
                try? await Task.sleep(for: .seconds(1.1))
                await enter(v)
            }
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
        sfx.play(.coin, volume: n >= 20 ? 0.9 : 0.6)
        if let c {
            scene?.pop(text: "+\(n) ¢", at: c, color: 0xE0A100)
            scene?.coinFountain(at: c, count: min(9, 3 + n / 10))
        }
    }

    // MARK: Passport stamps

    var stampEvent: StampEvent?
    @ObservationIgnored private var stampQueue: [StampEvent] = []

    /// Close the stamp ceremony and show the next one, if a bus ride collected several.
    func dismissStamp() {
        stampEvent = stampQueue.isEmpty ? nil : stampQueue.removeFirst()
    }

    // MARK: Bus

    private func busRide() async {
        guard let path = Rules.busRide(from: player.position, in: map), let scene else {
            gain(2, at: player.position)
            showToast("Bus stop, but no line here yet.", "+2 coins")
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
        let r = Rules.duel(you: a, them: b, weather: weather)
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
        map.owners[b] = BlockOwner(name: "You", city: player.homeCity ?? "your city")
        needs = Needs.of(map)
        if var d = draft {
            d.adopt(ownership: map.ownership, owners: map.owners)
            draft = d
            scene?.rebuildBlock(b, in: d.map)
        } else {
            scene?.rebuildBlock(b, in: map)
        }
        showToast("You bought plot \(b + 1)", b == 11 ? "The bus line runs along it: add a bus stop in Build." : "Tap the hammer to build on it.", seconds: 3)
        save()
    }

    // MARK: Build mode

    func enterBuild() {
        guard !isBusy, draft == nil else {
            if isBusy { showToast("Finish your move first.") }
            return
        }
        draft = BuildDraft(base: map)
        scene?.setBuildMode(true)
        scene?.focusForBuilding()
        showToast("Build mode", "Pick something below, then tap a square on your land.", seconds: 3.2)
    }

    /// Leave build mode. Changes you didn't open to the city are thrown away.
    func leaveBuild() {
        guard let d = draft else { return }
        draft = nil
        isUpgrading = false
        if d.hasChanges {
            scene?.showDraft(map, changed: d.changedCells)
            showToast("Unopened changes were set aside.")
        }
        scene?.showIssues(nil)
        scene?.setBuildMode(false)
        scene?.focusOnPawn()
    }

    func discardDraft() {
        guard let d = draft, d.hasChanges else { return }
        draft = BuildDraft(base: map)
        scene?.showDraft(map, changed: d.changedCells)
        scene?.showIssues(nil)
    }

    func paint(_ c: Cell) {
        if isUpgrading { upgrade(c); return }
        guard var d = draft else { return }
        let result = d.paint(c, buildTool, coins: player.coins, city: player.homeCity)
        switch result {
        case .painted:
            draft = d
            haptic.impactOccurred(intensity: 0.6)
            scene?.showDraft(d.map, changed: [c])
            scene?.showIssues(d.issues)
        case .unchanged:
            break
        case .notYourLand:
            if d.map.inBounds(c) {
                let b = d.map.block(of: c)
                showToast(d.map.ownership[b] == .forSale ? "Buy this plot to build here." : "That's \(d.map.owners[b].name)'s land.",
                          "You can only build on your own blocks.", seconds: 2)
            }
        case .busLine:
            showToast("The bus line runs on this street.", "Bus streets can't be built over.", seconds: 2)
        case .tooExpensive(let cost):
            showToast("Not enough coins for \(buildTool.isMonument ? "the" : "a") \(buildTool.noun)", "It costs \(cost). This draft already costs \(d.cost).", seconds: 2.4)
        case .onlyOne:
            showToast("You already have the \(buildTool.name).", "Each monument can be built once.", seconds: 2.4)
        case .notYourCity:
            showToast("The \(buildTool.name) belongs to another city.", seconds: 2.2)
        }
    }

    /// Step back one change in the draft.
    func undo() {
        guard var d = draft, d.canUndo else { return }
        let before = d.map
        d.undo()
        draft = d
        let changed = (0..<CityMap.size).flatMap { y in (0..<CityMap.size).compactMap { x in before.tiles[y][x] != d.map.tiles[y][x] ? Cell(x, y) : nil } }
        scene?.showDraft(d.map, changed: changed)
        scene?.showIssues(d.issues.isEmpty ? nil : d.issues)
    }

    /// Take away only the things that can't stay, keeping the rest of the draft.
    func removeProblems() {
        guard var d = draft else { return }
        let removed = d.removeProblems()
        guard !removed.isEmpty else { return }
        draft = d
        scene?.showDraft(d.map, changed: removed)
        scene?.showIssues(d.issues.isEmpty ? nil : d.issues)
        haptic.impactOccurred()
        showToast(d.issues.isEmpty ? "Fixed. Everything else stays." : "Fixed what I could.",
                  "\(removed.count) square\(removed.count == 1 ? "" : "s") changed back or cleared.", seconds: 2.4)
    }

    // MARK: Upgrades

    /// In build mode with the Upgrade tool, tapping your building raises it a level.
    var isUpgrading = false

    func upgrade(_ c: Cell) {
        guard let d = draft else { return }
        guard d.map.tiles[c.y][c.x] == d.base.tiles[c.y][c.x] else {
            showToast("Open your changes first.", "You can upgrade buildings that are already in the city.", seconds: 2.2)
            return
        }
        var coins = player.coins
        switch map.upgrade(c, coins: &coins) {
        case .upgraded(let level, let cost):
            player.coins = coins
            var nd = d
            nd.adoptLevels(map.levels)
            draft = nd
            needs = Needs.of(map)
            scene?.showDraft(nd.map, changed: [c])
            scene?.popIn([c])
            scene?.burst(at: c, colors: [0xF5B700, 0xFFE9A8, 0xFFFFFF], count: 18, height: 2)
            sfx.play(.upgrade)
            haptic.impactOccurred()
            let t = map.tiles[c.y][c.x]
            showToast("\(t.name) is now level \(level)", "Spent \(cost) coins. Visitors pay more here.", seconds: 2.4)
            save()
        case .maxed:
            showToast("This \(map.tiles[c.y][c.x].noun) is at the top level.")
        case .tooExpensive(let cost):
            showToast("Upgrading costs \(cost) coins.", "You have \(player.coins).")
        case .notYourBuilding:
            if map.tile(c)?.isMonument == true { showToast("Monuments are already as grand as they get.") }
            else { showToast("Tap one of your buildings to upgrade it.") }
        }
    }

    // MARK: Holiday pack

    /// Demo purchase of the running holiday's pack: its skin, decorations on your block and rolls.
    func buyHolidayPack() {
        guard let h = holiday, !player.packs.contains(h.id) else { return }
        player.buyPack(h)
        scene?.setHoliday(h, ownPack: true)
        equipSkin(Skin.named(h.packSkin))
        sfx.play(.achievement)
        showToast("\(h.name) pack unlocked", "Demo purchase, nothing was charged. +\(h.packRolls) rolls and decorations on your block.", seconds: 3.5)
        save()
    }

    // MARK: Home city

    var showCityPicker = false

    func chooseCity(_ city: String) {
        player.homeCity = city
        for b in map.myBlocks { map.owners[b].city = city }
        showCityPicker = false
        showToast("Welcome to \(city)", "Your city's monuments are in the build tray.", seconds: 2.6)
        save()
    }

    /// Happiness of your land if the draft were opened.
    var draftNeeds: Needs? { draft.map { Needs.of($0.map) } }

    func openToCity() {
        guard let d = draft, d.canOpen, player.coins >= d.cost else { return }
        map.tiles = d.map.tiles
        for c in d.changedCells { map.levels[c] = nil }
        player.coins -= d.cost
        needs = Needs.of(map)
        draft = nil
        isUpgrading = false

        // Anything standing on a street that is now built over moves to the nearest street.
        if !map.isRoad(player.position), let r = map.nearestRoad(to: player.position) {
            player.position = r
            player.heading = map.options(at: r, heading: .east).first ?? .east
            scene?.placePawn(at: r, heading: player.heading)
        }
        for i in ghosts.indices where !map.isRoad(ghosts[i].cell) {
            if let r = map.nearestRoad(to: ghosts[i].cell) {
                ghosts[i].cell = r
                scene?.placeGhost(ghosts[i].id, at: r)
            }
        }
        for c in pickups where !map.isRoad(c) {
            pickups.remove(c)
            scene?.removeCoin(at: c)
            dropCoin()
        }
        scene?.showDraft(map, changed: d.changedCells)
        scene?.showIssues(nil)
        scene?.setBuildMode(false)
        let built = d.changedCells.filter { map.tiles[$0.y][$0.x].isBuilding }
        scene?.popIn(built)
        for c in built.prefix(4) { scene?.burst(at: c, count: 14) }
        if let m = built.first(where: { map.tiles[$0.y][$0.x].isMonument }) {
            let t = map.tiles[m.y][m.x]
            scene?.burst(at: m, count: 40, height: 3)
            sfx.play(.achievement)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3.1))
                self?.showToast("You built the \(t.name)!", "Visitors pay \(t.visitValue)× here. Your block is happier.", seconds: 3.5)
            }
        } else {
            sfx.play(.build)
        }
        scene?.focusOnPawn()
        haptic.impactOccurred()
        showToast("Your changes are open to the city.", d.cost > 0 ? "Spent \(d.cost) coins. New squares are on the board now." : "New squares are on the board now.", seconds: 3)
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
            await scene.walkGhost(id, to: next)
            ghosts[i].cell = next
            ghosts[i].heading = d
        }
        if let f = map.frontage(of: ghosts[i].cell), map.ownership[f.block] == .mine, f.tile.isVisitable {
            let pay = max(1, Int((Double(f.tile.visitValue) * 4 * needs.visitMultiplier * map.levelFactor(at: f.cell)).rounded()))
            player.coins += pay
            player.earnedToday += pay
            player.visitsToday += 1
            let g = ghosts[i]
            scene.pop(text: "+\(pay) ¢", at: f.cell, color: 0xE0A100)
            if !isBuilding { scene.coinFountain(at: f.cell, count: 3) }
            sfx.play(.coin, volume: 0.35)
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
        let n = item.rolls
        if case .coins(let price) = item.price {
            guard player.coins >= price else { return }
            player.coins -= price
        }
        if case .money = item.price {
            showToast("Demo purchase: +\(n) rolls", "Nothing was charged.")
        } else {
            showToast("+\(n) rolls")
        }
        if item.isPass {
            player.goldenPawn = true
            player.ownedSkins.insert(Skin.gold.id)
            equipSkin(Skin.gold)
        }
        player.rolls += n
        save()
    }

    // MARK: Skins

    var showSkins = false

    /// Buy a skin with coins, then wear it.
    func buySkin(_ s: Skin) {
        guard player.buy(s) else { return }
        showToast("New look: \(s.name)")
        equipSkin(s)
    }

    func equipSkin(_ s: Skin) {
        player.equip(s)
        scene?.applySkin(player.skin, outfit: player.outfit)
        save()
    }

    // MARK: Music

    @ObservationIgnored let sfx = SoundFX()
    var soundOn: Bool = UserDefaults.standard.object(forKey: "giro.sfx") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(soundOn, forKey: "giro.sfx")
            sfx.isOn = soundOn
        }
    }

    @ObservationIgnored let music = MusicPlayer()
    var musicOn: Bool = UserDefaults.standard.object(forKey: "giro.music") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(musicOn, forKey: "giro.music")
            music.isOn = musicOn
        }
    }

    /// "h:mm:ss" for a countdown.
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    func claim(_ m: Mission) {
        if player.claim(m) {
            sfx.play(.achievement)
            scene?.burst(at: player.position, count: 30, height: 2)
            showToast("Mission done: +\(m.rewardRolls) rolls")
            save()
        }
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

    func save() {
        var tiles: [Int: [String]] = [:]
        for b in map.myBlocks {
            let o = CityMap.blockOrigin(b)
            tiles[b] = (o.y..<(o.y + CityMap.blockSize)).map { y in
                String((o.x..<(o.x + CityMap.blockSize)).map { map.tiles[y][$0].rawValue })
            }
        }
        let levels = Dictionary(uniqueKeysWithValues: map.levels.map { ("\($0.key.x),\($0.key.y)", $0.value) })
        let d = SaveData(player: player, ownership: map.ownership, myTiles: tiles, myLevels: levels)
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
            Account.shared.upload(data)
        }
        GameCenter.shared.report(stamps: player.stamps.count, landValue: map.myBlocks.reduce(0) { $0 + map.plotValue($1) })
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let d = try? JSONDecoder().decode(SaveData.self, from: data),
              d.ownership.count == map.ownership.count else { return }
        player = d.player
        map.ownership = d.ownership
        for b in map.ownership.indices where map.ownership[b] == .mine { map.owners[b] = BlockOwner(name: "You", city: player.homeCity ?? "your city") }
        for (k, l) in d.myLevels ?? [:] {
            let p = k.split(separator: ",").compactMap { Int($0) }
            if p.count == 2, map.inBounds(Cell(p[0], p[1])), map.ownership(of: Cell(p[0], p[1])) == .mine { map.levels[Cell(p[0], p[1])] = min(Tile.maxLevel, l) }
        }
        for (b, rows) in d.myTiles ?? [:] where map.ownership.indices.contains(b) && map.ownership[b] == .mine && rows.count == CityMap.blockSize {
            let o = CityMap.blockOrigin(b)
            for (dy, row) in rows.enumerated() where row.count == CityMap.blockSize {
                for (dx, ch) in row.enumerated() { if let t = Tile(rawValue: ch) { map.tiles[o.y + dy][o.x + dx] = t } }
            }
        }
        if !map.isRoad(player.position) { player.position = Cell(12, 14); player.heading = .east }
    }

    // MARK: Account

    /// Set when this phone and the account both have progress: the player picks which to keep.
    struct CloudChoice: Equatable { var data: Data; var coins: Int; var stamps: Int }
    var cloudChoice: CloudChoice?

    func signIn(_ result: Result<ASAuthorization, Error>) async {
        if await Account.shared.complete(result) { await syncAccount() }
    }

    func signOut() { Account.shared.signOut() }

    private func syncAccount() async {
        switch await Account.shared.sync(hasLocalSave: hasSave) {
        case .failed: return
        case .keepPhone: Account.shared.markReady(); save()
        case .useCloud(let data): restore(data)
        case .ask(let data):
            guard let s = try? JSONDecoder().decode(SaveData.self, from: data) else { Account.shared.markReady(); save(); return }
            cloudChoice = CloudChoice(data: data, coins: s.player.coins, stamps: s.player.stamps.count)
        }
    }

    func resolveCloudChoice(keepCloud: Bool) {
        guard let c = cloudChoice else { return }
        cloudChoice = nil
        if keepCloud { restore(c.data) } else { Account.shared.markReady(); save() }
    }

    /// Replace this phone's game with a save from the cloud.
    private func restore(_ data: Data) {
        if let d = try? JSONDecoder().decode(SaveData.self, from: data), d.ownership.count == map.ownership.count {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
            player = PlayerState()
            draft = nil
            map = CityMap.example()
            load()
            needs = Needs.of(map)
            scene?.rebuildAll(map: map, pawnAt: player.position)
            scene?.applySkin(player.skin, outfit: player.outfit)
        }
        Account.shared.markReady()
        save()
    }

    func resetProgress() {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
        player = PlayerState()
        draft = nil
        map = CityMap.example()
        needs = Needs.of(map)
        scene?.rebuildAll(map: map, pawnAt: player.position)
        scene?.applySkin(player.skin, outfit: player.outfit)
    }
}
