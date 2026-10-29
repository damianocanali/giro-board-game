import XCTest
@testable import GiroCore

final class CityMapTests: XCTestCase {
    let map = CityMap.example()

    func testHomeBlockMatchesPrototype() {
        let home = [".h=s..", "hp=hcs", "======", "hh=p=o", ".a===h", ".f=hp."]
        for (dy, row) in home.enumerated() {
            for (dx, ch) in row.enumerated() {
                XCTAssertEqual(map.tiles[12 + dy][12 + dx].rawValue, ch, "at \(12 + dx),\(12 + dy)")
            }
        }
        XCTAssertEqual(map.ownership[CityMap.homeBlock], .mine)
        XCTAssertEqual(Set(map.ownership.indices.filter { map.ownership[$0] == .forSale }), [11, 13, 17])
    }

    func testGenerationIsDeterministic() {
        XCTAssertEqual(CityMap.example().tiles, map.tiles)
    }

    func testBusRouteIsAllRoad() {
        XCTAssertEqual(map.busRoute.count, 50)
        XCTAssertTrue(map.busRoute.allSatisfy { map.isRoad($0) })
        XCTAssertEqual(map.busStopIndices, [2, 12, 14, 22])
    }

    func testForkAtFirstCrossing() {
        XCTAssertEqual(map.options(at: Cell(14, 14), heading: .east), [.east, .south, .north])
        XCTAssertEqual(map.options(at: Cell(13, 14), heading: .east), [.east])
        XCTAssertTrue(map.isIntersection(Cell(14, 14)))
    }

    func testWalkMatchesPrototype() {
        // Prototype: from home, roll 4, pick the first option at the fork -> lands on (16,14), the home block.
        let r = Rules.walk(from: Cell(12, 14), heading: .east, steps: 4, in: map) { _ in 0 }
        XCTAssertEqual(r.path.last, Cell(16, 14))
        XCTAssertEqual(Rules.landing(on: Cell(16, 14), in: map, multiplier: 1), .home)
    }

    func testOwnBuildingsWinFrontage() {
        let f = map.frontage(of: Cell(17, 14))
        XCTAssertEqual(f?.tile, .shop)
        XCTAssertEqual(map.squareKind(f), .home)
    }

    func testBusRideGoesToNextStop() {
        XCTAssertEqual(Rules.busRide(from: Cell(10, 9), in: map)?.last, Cell(20, 9))
        XCTAssertNil(Rules.busRide(from: Cell(12, 14), in: map))
    }

    func testExampleCityHasNoBuildIssues() {
        XCTAssertTrue(map.buildIssues().isEmpty)
    }

    func testBrokenBorderStreetIsReported() {
        var m = map
        m.tiles[12][12] = .road // top-left corner of home block, neighbour above is not a street
        XCTAssertTrue(m.buildIssues().brokenEdges.contains(Cell(12, 12)))
        m.tiles[12][12] = .empty
        m.tiles[14][12] = .empty // cut the street that continues west
        XCTAssertTrue(m.buildIssues().brokenEdges.contains(Cell(12, 14)))
        XCTAssertTrue(m.buildIssues().unreachable.contains(Cell(12, 13)))
    }

    func testLandingRewardsScaleWithMultiplier() {
        // Find any street square facing another player's shop and check the payout scales.
        let shopSquare = map.roadCells.first { map.squareKind(map.frontage(of: $0)) == .shop }!
        guard case .coins(let a1, .shop, _) = Rules.landing(on: shopSquare, in: map, multiplier: 1),
              case .coins(let a3, .shop, _) = Rules.landing(on: shopSquare, in: map, multiplier: 3) else {
            return XCTFail("expected a shop landing")
        }
        XCTAssertEqual(a3, a1 * 3)
    }

    func testNeedsOfExampleBlock() {
        let n = Needs.of(map)
        XCTAssertEqual(n.residents, 40)
        XCTAssertEqual(n.transit, 0)
        XCTAssertEqual(n.green, 1)
    }
}

final class EconomyTests: XCTestCase {
    func testDailyRefillTopsUpOncePerDay() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Rome")!
        let morning = cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!
        var p = PlayerState()
        p.rolls = 4; p.lastRefill = morning; p.claimed = [.bus]
        // Same day: nothing, and the countdown points at midnight (15 hours away).
        XCTAssertEqual(p.refillIfNewDay(now: morning.addingTimeInterval(3600), calendar: cal), 0)
        XCTAssertEqual(p.secondsToRefill(now: morning, calendar: cal), 15 * 3600)
        // Just after midnight: back to the daily allowance and missions reset.
        let next = cal.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 0, minute: 1))!
        XCTAssertEqual(p.refillIfNewDay(now: next, calendar: cal), GameConfig.dailyRolls - 4)
        XCTAssertEqual(p.rolls, GameConfig.dailyRolls)
        XCTAssertTrue(p.claimed.isEmpty)
        XCTAssertNil(p.secondsToRefill(now: next, calendar: cal))
        XCTAssertEqual(p.refillIfNewDay(now: next.addingTimeInterval(60), calendar: cal), 0)
    }

    func testRefillKeepsBonusRolls() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        var p = PlayerState()
        p.rolls = 75; p.lastRefill = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(p.refillIfNewDay(now: Date(timeIntervalSince1970: 90_000), calendar: cal), 0)
        XCTAssertEqual(p.rolls, 75)
    }

    func testSkinsBuyEquipAndOldSavesLoad() throws {
        var p = PlayerState()
        let mint = Skin.named("mint")
        p.coins = 100
        XCTAssertFalse(p.buy(mint))
        p.equip(mint)
        XCTAssertEqual(p.skinID, Skin.classic.id)
        p.coins = 500
        XCTAssertTrue(p.buy(mint))
        XCTAssertEqual(p.coins, 100)
        p.equip(mint)
        XCTAssertEqual(p.skin, mint)
        XCTAssertFalse(p.buy(Skin.gold), "the golden skin comes with the pass, not coins")
        // A save from before skins and daily rolls still loads, and the pass unlocks the golden skin.
        let old = #"{"coins":42,"rolls":7,"multiplier":1,"position":{"x":12,"y":14},"heading":{"dx":1,"dy":0},"stamps":[],"progress":[],"claimed":[],"goldenPawn":true,"lastRegen":0,"visitsToday":0,"earnedToday":0,"busRides":0}"#
        let q = try JSONDecoder().decode(PlayerState.self, from: Data(old.utf8))
        XCTAssertEqual(q.coins, 42)
        XCTAssertEqual(q.rolls, 7)
        XCTAssertTrue(q.owns(Skin.gold))
        XCTAssertEqual(q.skinID, Skin.classic.id)
        XCTAssertEqual(q.outfit, .starter, "an old save starts in the starter outfit")
    }

    func testStores() throws {
        // Every shop and café is a store with something on the shelves; houses aren't.
        XCTAssertEqual(StoreKind.of(.cafe, at: Cell(3, 4)), .cafe)
        XCTAssertNil(StoreKind.of(.house, at: Cell(3, 4)))
        XCTAssertEqual(Set((0..<40).compactMap { StoreKind.of(.shop, at: Cell($0, $0 * 3)) }).count, 4)
        for k in StoreKind.allCases { XCTAssertFalse(k.items.isEmpty, "\(k) has stock") }
        XCTAssertEqual(Set(StoreItem.catalog.map(\.id)).count, StoreItem.catalog.count, "ids are unique")

        var p = PlayerState()
        p.coins = 1000
        let hoodie = try XCTUnwrap(StoreItem.named("hoodie-blue")), dress = try XCTUnwrap(StoreItem.named("dress-pink"))
        let jeans = try XCTUnwrap(StoreItem.named("jeans")), dog = try XCTUnwrap(StoreItem.named("pet-dog"))
        XCTAssertEqual(p.buy(hoodie), .ok)
        XCTAssertTrue(p.isWearing(hoodie))
        XCTAssertEqual(p.buy(hoodie), .alreadyOwned)
        XCTAssertEqual(p.buy(jeans), .ok)
        XCTAssertEqual(p.buy(dress), .ok)
        XCTAssertEqual(p.outfit.bottom, .none, "a dress takes the jeans off")
        p.wear(jeans)
        XCTAssertEqual(p.outfit.top, .none, "jeans take the dress off")
        XCTAssertEqual(p.coins, 1000 - 260 - 200 - 340)
        XCTAssertEqual(p.buy(dog), .tooExpensive)

        // Selling pays half and takes the item off.
        XCTAssertEqual(p.sell(jeans), 100)
        XCTAssertFalse(p.owns(jeans))
        XCTAssertEqual(p.outfit.bottom, .none)
        XCTAssertNil(p.sell(jeans))

        // Food gives rolls, up to a daily cap; the free café snack counts towards it.
        p.coins = 5000
        let rolls = p.rolls
        XCTAssertTrue(p.takeFreeSnack())
        XCTAssertFalse(p.takeFreeSnack())
        let picnic = try XCTUnwrap(StoreItem.named("picnic"))
        XCTAssertEqual(p.buy(picnic), .ok)
        XCTAssertEqual(p.buy(picnic), .full)
        XCTAssertEqual(p.rolls, rolls + 5)
        XCTAssertNil(p.sell(picnic), "food can't be sold")

        // Pets walk with you until sent home; a new day resets food.
        XCTAssertEqual(p.buy(dog), .ok)
        XCTAssertEqual(p.pet, dog.id)
        p.takeOff(dog)
        XCTAssertNil(p.pet)
        p.lastRefill = Date().addingTimeInterval(-3 * 86400)
        p.refillIfNewDay(now: Date())
        XCTAssertEqual(p.foodRollsLeft, StoreItem.dailyFoodRolls)
        XCTAssertFalse(p.freeSnackTaken)
        XCTAssertEqual(try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(p)), p)
    }

    func testOutfit() throws {
        // A dress hides any bottom; other players' sample outfits are stable and always valid.
        XCTAssertEqual(Outfit(top: .dress, bottom: .trousers).normalized.bottom, .none)
        XCTAssertEqual(Outfit.sample(5), Outfit.sample(5))
        for i in 0..<40 { let o = Outfit.sample(i); XCTAssertEqual(o, o.normalized) }
        XCTAssertGreaterThan(Set((0..<20).map(Outfit.sample)).count, 5, "players don't all dress alike")
        var p = PlayerState()
        p.outfit = Outfit(top: .hoodie, topColor: 0x123456, shoes: .boots)
        XCTAssertEqual(try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(p)).outfit, p.outfit)
    }

    func testMultiplierNeedsEnoughRolls() {
        var p = PlayerState()
        p.rolls = 2
        p.cycleMultiplier(); XCTAssertEqual(p.multiplier, 2)
        p.cycleMultiplier(); XCTAssertEqual(p.multiplier, 1)
        p.multiplier = 2
        XCTAssertTrue(p.spendRoll()); XCTAssertEqual(p.rolls, 0)
        XCTAssertFalse(p.spendRoll())
    }

    func testMissionClaimOnlyOnce() {
        var p = PlayerState()
        let bus = Mission.daily.first { $0.id == .bus }!
        XCTAssertFalse(p.claim(bus))
        p.advance(.bus)
        let before = p.rolls
        XCTAssertTrue(p.claim(bus)); XCTAssertEqual(p.rolls, before + bus.rewardRolls)
        XCTAssertFalse(p.claim(bus))
    }

    func testCrateOddsArePublishedAndConsistent() {
        XCTAssertEqual(ShopItem.crateOdds.map(\.chance).reduce(0, +), 1, accuracy: 1e-9)
        XCTAssertEqual(ShopItem.openCrate(roll: 0.49), 3)
        XCTAssertEqual(ShopItem.openCrate(roll: 0.79), 6)
        XCTAssertEqual(ShopItem.openCrate(roll: 0.94), 12)
        XCTAssertEqual(ShopItem.openCrate(roll: 0.999), 25)
        XCTAssertTrue(ShopItem.crateOddsText.contains("25 rolls 5%"))
    }

    func testDuel() {
        XCTAssertEqual(Rules.duel(you: 6, them: 2, multiplier: 2), .win(80))
        XCTAssertEqual(Rules.duel(you: 3, them: 3, multiplier: 1), .tie(10))
        XCTAssertEqual(Rules.duel(you: 1, them: 4, multiplier: 1), .lose)
    }

    func testStateRoundTripsThroughJSON() throws {
        var p = PlayerState()
        p.stamps = [1, 8]; p.advance(.pickups, by: 3); p.claimed = [.bus]
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(PlayerState.self, from: data), p)
    }
}

final class BuildDraftTests: XCTestCase {
    func testCannotPaintOtherPlayersLand() {
        var d = BuildDraft(base: CityMap.example())
        XCTAssertEqual(d.paint(Cell(0, 0), .shop, coins: 999), .notYourLand)
        XCTAssertFalse(d.hasChanges)
    }

    func testCostCountsOnlyChangesAgainstTheCity() {
        var d = BuildDraft(base: CityMap.example())
        // (12,12) is empty on the home block.
        XCTAssertEqual(d.paint(Cell(12, 12), .shop, coins: 500), .painted)
        XCTAssertEqual(d.cost, Tile.shop.cost)
        XCTAssertEqual(d.paint(Cell(12, 12), .office, coins: 500), .painted)
        XCTAssertEqual(d.cost, Tile.office.cost)
        XCTAssertEqual(d.paint(Cell(12, 12), .empty, coins: 500), .painted)
        XCTAssertEqual(d.cost, 0)
        XCTAssertFalse(d.hasChanges)
    }

    func testClearingIsFree() {
        var d = BuildDraft(base: CityMap.example())
        XCTAssertEqual(d.paint(Cell(13, 12), .empty, coins: 0), .painted) // the house at (13,12)
        XCTAssertEqual(d.cost, 0)
        XCTAssertTrue(d.canOpen)
    }

    func testCannotSpendMoreThanYouHave() {
        var d = BuildDraft(base: CityMap.example())
        XCTAssertEqual(d.paint(Cell(12, 12), .office, coins: 50), .tooExpensive(cost: Tile.office.cost))
        XCTAssertEqual(d.paint(Cell(12, 12), .park, coins: 50), .painted)
    }

    func testRepaintingSameTileIsUnchanged() {
        var d = BuildDraft(base: CityMap.example())
        XCTAssertEqual(d.paint(Cell(13, 12), .house, coins: 500), .unchanged)
    }

    func testBorderStreetMustMeetNeighbour() {
        var d = BuildDraft(base: CityMap.example())
        // (12,14) is a street at the west border that continues the neighbour's street.
        XCTAssertEqual(d.paint(Cell(12, 14), .park, coins: 500), .painted)
        XCTAssertTrue(d.issues.brokenEdges.contains(Cell(12, 14)))
        XCTAssertFalse(d.canOpen)
    }

    func testIsolatedStreetIsDisconnected() {
        var d = BuildDraft(base: CityMap.example())
        // (17,17) is an empty corner; a lone street there joins nothing.
        XCTAssertEqual(d.base.tiles[17][17], .empty)
        d.paint(Cell(17, 17), .road, coins: 500)
        XCTAssertEqual(d.issues.disconnected, [Cell(17, 17)])
        // Joining it to the street at (16,16) via (16,17)... (16,17) is a park, (17,16) is a house: pave (17,16).
        d.paint(Cell(17, 16), .road, coins: 500)
        XCTAssertTrue(d.issues.disconnected.isEmpty, "\(d.issues)")
    }

    func testBuildingNeedsStreet() {
        var d = BuildDraft(base: CityMap.example())
        d.paint(Cell(17, 17), .shop, coins: 500)
        XCTAssertTrue(d.issues.unreachable.contains(Cell(17, 17)))
    }

    func testBusLineStreetsAreProtected() {
        var m = CityMap.example()
        m.ownership[11] = .mine // plot 11 has the bus line on x = 8
        var d = BuildDraft(base: m)
        XCTAssertEqual(d.paint(Cell(8, 14), .park, coins: 500), .busLine)
    }

    func testNearestRoad() {
        let m = CityMap.example()
        XCTAssertEqual(m.nearestRoad(to: Cell(14, 14)), Cell(14, 14))
        XCTAssertNotNil(m.nearestRoad(to: Cell(13, 12)))
        XCTAssertTrue(m.isRoad(m.nearestRoad(to: Cell(13, 12))!))
    }
}

final class MonumentAndUpgradeTests: XCTestCase {
    /// A house on your home block next to a street (to build over).
    private func spot(_ m: CityMap) -> Cell {
        let o = CityMap.blockOrigin(CityMap.homeBlock)
        for y in o.y..<(o.y + CityMap.blockSize) { for x in o.x..<(o.x + CityMap.blockSize) {
            let c = Cell(x, y)
            if m.tiles[y][x] == .house && Dir.optionOrder.contains(where: { m.isRoad(c.moved($0)) }) { return c }
        } }
        fatalError("no free spot")
    }

    func testMonumentsOnlyForYourCityAndOnlyOnce() {
        let m = CityMap.example()
        var d = BuildDraft(base: m)
        let c = spot(m)
        XCTAssertEqual(d.paint(c, .eiffel, coins: 5000, city: "New York"), .notYourCity)
        XCTAssertEqual(d.paint(c, .liberty, coins: 5000, city: "New York"), .painted)
        XCTAssertTrue(d.issues.isEmpty)
        let other = Cell(c.x == 12 ? 17 : 12, 17)
        XCTAssertEqual(d.paint(other, .liberty, coins: 5000, city: "New York"), .onlyOne)
        XCTAssertEqual(Tile.monuments(in: "Brooklyn"), [.liberty, .empireState])
    }

    func testOtherPlayersHaveTheirMonumentsAndPayVisitors() {
        let m = CityMap.example()
        let roma = m.owners.firstIndex { $0.city == "Roma" }!
        let o = CityMap.blockOrigin(roma)
        let cell = (o.y..<(o.y + 6)).flatMap { y in (o.x..<(o.x + 6)).map { Cell($0, y) } }.first { m.tile($0) == .colosseum }
        XCTAssertNotNil(cell, "Giulia from Roma has the Colosseum")
        let street = Dir.optionOrder.map { cell!.moved($0) }.first { m.isRoad($0) && m.frontage(of: $0)?.tile == .colosseum }
        if let street {
            XCTAssertEqual(Rules.landing(on: street, in: m, multiplier: 2), .coins(amount: GameConfig.landmarkCoins * 2, place: .colosseum, block: roma))
        }
    }

    func testRemoveProblemsKeepsGoodBuildings() {
        let m = CityMap.example()
        var d = BuildDraft(base: m)
        let good = spot(m)
        XCTAssertEqual(d.paint(good, .cafe, coins: 1000), .painted)
        // A house in the middle of a street with its only neighbours cut off: find a square with no street beside it.
        let o = CityMap.blockOrigin(CityMap.homeBlock)
        var lonely: Cell?
        for y in o.y..<(o.y + 6) { for x in o.x..<(o.x + 6) {
            let c = Cell(x, y)
            if lonely == nil, d.map.tile(c) != .road, !Dir.optionOrder.contains(where: { d.map.isRoad(c.moved($0)) }) { lonely = c }
        } }
        guard let bad = lonely else { return }
        XCTAssertEqual(d.paint(bad, .shop, coins: 1000), .painted)
        XCTAssertFalse(d.issues.isEmpty)
        let removed = d.removeProblems()
        XCTAssertEqual(removed, [bad])
        XCTAssertTrue(d.issues.isEmpty)
        XCTAssertEqual(d.map.tile(good), .cafe)
        d.undo()
        XCTAssertEqual(d.map.tile(bad), .shop)
        d.undo(); d.undo()
        XCTAssertFalse(d.hasChanges)
    }

    func testUpgradesCostMoreAndStopAtMax() {
        var m = CityMap.example()
        let o = CityMap.blockOrigin(CityMap.homeBlock)
        let shop = (o.y..<(o.y + 6)).flatMap { y in (o.x..<(o.x + 6)).map { Cell($0, y) } }.first { m.tile($0) == .shop }!
        var coins = 10_000
        let before = Needs.of(m)
        XCTAssertEqual(m.upgrade(shop, coins: &coins), .upgraded(level: 2, cost: Tile.shop.cost * 3))
        XCTAssertEqual(m.upgrade(shop, coins: &coins), .upgraded(level: 3, cost: Tile.shop.cost * 6))
        XCTAssertEqual(m.upgrade(shop, coins: &coins), .maxed)
        XCTAssertEqual(coins, 10_000 - Tile.shop.cost * 9)
        XCTAssertGreaterThanOrEqual(Needs.of(m).shopping, before.shopping)
        var poor = 1
        XCTAssertEqual(m.upgrade(Cell(0, 0), coins: &poor), .notYourBuilding)
    }
}

final class SeasonTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func date(_ m: Int, _ d: Int, _ h: Int = 12, year: Int = 2026) -> Date { cal.date(from: DateComponents(year: year, month: m, day: d, hour: h))! }

    func testWeatherIsStableWithinASlotAndNeverSnowsInSummer() {
        XCTAssertEqual(Weather.at(date(7, 1, 9), calendar: cal), Weather.at(date(7, 1, 11), calendar: cal))
        for d in 1...31 { for h in stride(from: 0, to: 24, by: 3) { XCTAssertNotEqual(Weather.at(date(7, d, h), calendar: cal), .snow) } }
        XCTAssertEqual(Weather.nextChange(after: date(7, 1, 10), calendar: cal), date(7, 1, 12))
    }

    func testWeatherChangesTheRules() {
        let m = CityMap.example()
        let shopStreet = m.roadCells.first { m.squareKind(m.frontage(of: $0)) == .shop }!
        guard case .coins(let dry, _, _) = Rules.landing(on: shopStreet, in: m, multiplier: 1, weather: .sunny),
              case .coins(let wet, _, _) = Rules.landing(on: shopStreet, in: m, multiplier: 1, weather: .rain) else { return XCTFail() }
        XCTAssertEqual(wet, dry * 2)
        XCTAssertEqual(Rules.duel(you: 6, them: 1, multiplier: 1, weather: .snow), .win(GameConfig.duelWinCoins * 2))
    }

    func testHolidayWindowsAndEventReward() {
        XCTAssertEqual(Holiday.active(at: date(10, 28), calendar: cal)?.id, "halloween")
        XCTAssertEqual(Holiday.active(at: date(1, 3), calendar: cal)?.id, "winter")
        XCTAssertNil(Holiday.active(at: date(7, 1), calendar: cal))
        let h = Holiday.active(at: date(10, 28), calendar: cal)!
        XCTAssertEqual(h.daysLeft(from: date(10, 28), calendar: cal), 6)
        var p = PlayerState()
        for _ in 1..<h.goal { XCTAssertFalse(p.collectToken(for: h)) }
        XCTAssertTrue(p.collectToken(for: h))
        XCTAssertTrue(p.ownedSkins.contains("pumpkin"))
        p.buyPack(h)
        XCTAssertTrue(p.ownedSkins.contains("witch"))
    }

    func testPlotValueRisesWithBuildingsAndUpgrades() {
        var m = CityMap.example()
        let home = CityMap.homeBlock
        let before = m.plotValue(home)
        let o = CityMap.blockOrigin(home)
        let shop = (o.y..<(o.y + 6)).flatMap { y in (o.x..<(o.x + 6)).map { Cell($0, y) } }.first { m.tile($0) == .shop }!
        var coins = 10_000
        _ = m.upgrade(shop, coins: &coins)
        XCTAssertGreaterThan(m.plotValue(home), before)
        // The bare plot on the bus line is worth more than a bare plot in a corner would be on location alone.
        XCTAssertGreaterThan(m.plotValue(11), 220)
    }
}
