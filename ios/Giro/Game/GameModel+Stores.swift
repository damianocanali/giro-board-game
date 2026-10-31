import SwiftUI

/// Being inside one store: what kind it is and whose it is.
/// The circle wipe used for going in and out of buildings. `center` nil means the middle of the screen.
struct Iris: Equatable {
    var center: CGPoint?
    var closed = false
    var label: String
}

struct StoreVisit: Identifiable, Equatable {
    var cell: Cell
    var kind: StoreKind
    var owner: String
    var city: String
    var id: Cell { cell }
}

extension PlayerState {
    var petItem: StoreItem? { pet.flatMap(StoreItem.named) }
}

extension GameModel {
    /// The store a street square faces, if that building is one.
    func store(facing c: Cell) -> StoreVisit? {
        guard let f = map.frontage(of: c) else { return nil }
        let mine = map.ownership[f.block] == .mine
        let o = map.owners[f.block]
        if mine && (f.tile == .house || f.tile == .apartments) {
            return StoreVisit(cell: f.cell, kind: .home, owner: "Your", city: player.homeCity ?? o.city)
        }
        guard let kind = StoreKind.of(f.tile, at: f.cell) else { return nil }
        return StoreVisit(cell: f.cell, kind: kind, owner: mine ? "Your" : "\(o.name)'s", city: o.city)
    }

    /// The store next to where you are standing, while nothing else is going on.
    var nearbyStore: StoreVisit? {
        guard !isBusy, !isBuilding, forkChoices.isEmpty, storeVisit == nil, iris == nil else { return nil }
        return store(facing: player.position)
    }

    func enterNearbyStore() {
        guard let v = nearbyStore else { return }
        Task { await enter(v) }
    }

    /// The camera glides to the door, it swings open, you walk into the doorway,
    /// and a circle closes on it and opens again inside the room.
    func enter(_ v: StoreVisit) async {
        guard storeVisit == nil, iris == nil, let scene else { return }
        sfx.play(.coin, volume: 0.3)
        scene.openDoor(of: v.cell)
        await scene.walkIntoDoorway()
        await closeIris(on: scene.doorScreenPoint, label: v.kind == .home ? "Home" : "\(v.owner) \(v.kind.name.lowercased())")
        scene.showInterior(v, skin: player.skin, outfit: player.outfit, pet: player.petItem)
        storeVisit = v
        try? await Task.sleep(for: .milliseconds(200))
        await openIris(on: nil)
    }

    /// The same circle in reverse: it opens on the doorway, you step out, and the door shuts behind you.
    func leaveStore() {
        guard storeVisit != nil, iris == nil else { return }
        Task {
            await closeIris(on: nil, label: "")
            storeVisit = nil
            scene?.hideInterior()
            scene?.placePawn(at: player.position, heading: player.heading)
            try? await Task.sleep(for: .milliseconds(150))
            async let out: Void = scene?.stepOutOfDoorway(to: player.position) ?? ()
            await openIris(on: scene?.doorScreenPoint)
            await out
        }
    }

    private func closeIris(on p: CGPoint?, label: String) async {
        iris = Iris(center: p, label: label)
        try? await Task.sleep(for: .milliseconds(30))
        withAnimation(.easeIn(duration: 0.45)) { iris?.closed = true }
        try? await Task.sleep(for: .milliseconds(500))
    }

    private func openIris(on p: CGPoint?) async {
        iris?.center = p
        try? await Task.sleep(for: .milliseconds(30))
        withAnimation(.easeOut(duration: 0.5)) { iris?.closed = false }
        try? await Task.sleep(for: .milliseconds(520))
        iris = nil
    }

    /// A building was tapped in the city: go in if it is a store right next to you.
    func tapPlace(_ c: Cell) {
        guard let v = nearbyStore, v.cell == c else { return }
        enterNearbyStore()
    }

    func buyItem(_ item: StoreItem) {
        switch player.buy(item) {
        case .ok:
            if case .food(let r) = item.thing {
                showToast("Yum! \(item.emoji)", "+\(r) roll\(r > 1 ? "s" : "") of energy")
            } else if item.isPet {
                showToast("\(item.emoji) \(item.name) is coming home with you!")
            } else {
                showToast("New \(item.name.lowercased()) \(item.emoji)", "You're wearing it.")
            }
            sfx.play(.coin)
            refreshLook()
        case .full:
            showToast("You're full for today", "Food can give \(StoreItem.dailyFoodRolls) rolls a day.")
        case .tooExpensive:
            showToast("Not enough coins")
        case .alreadyOwned:
            break
        }
    }

    func sellItem(_ item: StoreItem) {
        guard let paid = player.sell(item) else { return }
        showToast("Sold the \(item.name.lowercased())", "+\(paid) coins")
        sfx.play(.coin, volume: 0.6)
        refreshLook()
    }

    /// Put it on, or take it off if you are already wearing it.
    func toggleWear(_ item: StoreItem) {
        if player.isWearing(item) { player.takeOff(item) } else { player.wear(item) }
        refreshLook()
    }

    func takeFreeSnack() {
        guard player.takeFreeSnack() else { return }
        showToast("Free snack! ☕️", "+\(StoreItem.freeSnackRolls) roll of energy")
        sfx.play(.coin)
        save()
    }

    private func refreshLook() {
        scene?.applySkin(player.skin, outfit: player.outfit)
        scene?.setPet(player.petItem)
        if let v = storeVisit { scene?.refreshVisitor(skin: player.skin, outfit: player.outfit, pet: player.petItem, home: v.kind == .home) }
        save()
    }
}
