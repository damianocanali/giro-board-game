import Foundation

/// Being inside one store: what kind it is and whose it is.
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
        guard !isBusy, !isBuilding, forkChoices.isEmpty, storeVisit == nil, doorFade == nil else { return nil }
        return store(facing: player.position)
    }

    func enterNearbyStore() {
        guard let v = nearbyStore else { return }
        Task { await enter(v) }
    }

    /// Walk to the door, fade out with a spinner, and come in to the room.
    func enter(_ v: StoreVisit) async {
        guard storeVisit == nil, doorFade == nil, let scene else { return }
        sfx.play(.coin, volume: 0.3)
        await scene.walkTowardDoor(of: v.cell)
        doorFade = v.kind == .home ? "Going home…" : "Going into \(v.owner) \(v.kind.name.lowercased())…"
        try? await Task.sleep(for: .milliseconds(450))
        scene.showInterior(v, skin: player.skin, outfit: player.outfit, pet: player.petItem)
        storeVisit = v
        try? await Task.sleep(for: .milliseconds(550))
        doorFade = nil
    }

    /// Fade out, back on the street where you were.
    func leaveStore() {
        guard storeVisit != nil, doorFade == nil else { return }
        doorFade = "Back to the street…"
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            storeVisit = nil
            scene?.hideInterior()
            scene?.placePawn(at: player.position, heading: player.heading)
            try? await Task.sleep(for: .milliseconds(350))
            doorFade = nil
        }
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
