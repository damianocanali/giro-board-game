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
    func testRegenerationIsCapped() {
        var p = PlayerState()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        p.rolls = 18; p.lastRegen = t0
        XCTAssertEqual(p.regenerate(now: t0.addingTimeInterval(GameConfig.rollRegenSeconds * 5 + 1)), 2)
        XCTAssertEqual(p.rolls, GameConfig.rollCap)
        XCTAssertNil(p.secondsToNextRoll(now: t0))
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
