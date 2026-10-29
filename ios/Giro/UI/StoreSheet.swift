import SwiftUI

/// Inside a store: a little shopfront scene, then the shelves. Buy, wear, eat or sell back for half.
struct StoreSheet: View {
    let model: GameModel
    let visit: StoreVisit
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    StoreInterior(visit: visit)
                    if visit.kind == .cafe || visit.kind == .grocery { energy }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visit.kind.items) { item in StoreItemCard(model: model, item: item) }
                    }
                    if visit.kind != .cafe && visit.kind != .grocery {
                        Text("Shops buy back anything you own for half what you paid. Selling to other players comes with online play.")
                            .font(Theme.body(12)).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
                    }
                }
                .padding(16)
            }
            .background(Theme.paper)
            .navigationTitle("\(visit.owner) \(visit.kind.name.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Leave") { model.storeVisit = nil } } }
        }
        .tint(Theme.ink)
    }

    /// Food is energy: rolls left to eat today, and the café's free daily snack.
    private var energy: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Energy from food today").font(Theme.body(14, .bold))
                Spacer()
                Text("\(model.player.foodRollsLeft) of \(StoreItem.dailyFoodRolls) rolls left").font(Theme.body(13, .bold)).foregroundStyle(Theme.ink2)
            }
            ProgressView(value: Double(model.player.foodRollsToday), total: Double(StoreItem.dailyFoodRolls)).tint(Theme.good)
            if visit.kind == .cafe {
                if model.player.freeSnackTaken {
                    Text("You've had today's free snack. Come back tomorrow!").font(Theme.body(13)).foregroundStyle(Theme.ink2)
                } else {
                    Button("Free daily snack: +\(StoreItem.freeSnackRolls) roll") { model.takeFreeSnack() }
                        .buttonStyle(CardButtonStyle())
                        .disabled(model.player.foodRollsLeft < StoreItem.freeSnackRolls)
                }
            }
        }
        .padding(14)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// A drawn shop interior: coloured wall, shelves with the stock on them and the counter.
private struct StoreInterior: View {
    let visit: StoreVisit

    private var wall: Color {
        switch visit.kind {
        case .clothes: Color(hex: 0xF7D9E3)
        case .shoes: Color(hex: 0xDCE8F5)
        case .pets: Color(hex: 0xDDEFD6)
        case .grocery: Color(hex: 0xFBE7C2)
        case .cafe: Color(hex: 0xEAD7C3)
        }
    }

    var body: some View {
        let stock = visit.kind.items.map(\.emoji)
        VStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { row in
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { i in
                            Text(stock[(row * 6 + i) % stock.count]).font(.system(size: 26))
                        }
                    }
                    .frame(height: 38)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xB8784A)).frame(height: 7)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
            Spacer(minLength: 12)
            HStack {
                Text("Welcome to \(visit.owner.lowercased() == "your" ? "your" : visit.owner) \(visit.kind.name.lowercased()) in \(visit.city)!")
                    .font(Theme.body(13, .bold)).foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color(hex: 0x8A5A3B).opacity(0.25))
        }
        .frame(height: 170)
        .background(wall)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(visit.owner) \(visit.kind.name) in \(visit.city)")
    }
}

private struct StoreItemCard: View {
    let model: GameModel
    let item: StoreItem

    private var owned: Bool { model.player.owns(item) }
    private var wearing: Bool { owned && model.player.isWearing(item) }

    var body: some View {
        VStack(spacing: 8) {
            icon
                .frame(width: 64, height: 64)
                .background(Theme.paper, in: Circle())
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            Text(item.name).font(Theme.body(15, .heavy)).foregroundStyle(Theme.ink)
            Text(detail).font(Theme.body(12)).foregroundStyle(Theme.ink2)
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(wearing ? Theme.you : Theme.line, lineWidth: wearing ? 3 : 1))
    }

    /// Clothes and shoes: the emoji drained of colour and dyed the item's own colour, so a red tee looks red.
    @ViewBuilder private var icon: some View {
        let e = Text(item.emoji).font(.system(size: 40))
        switch item.thing {
        case .top(_, let c), .bottom(_, let c), .shoes(_, let c):
            e.saturation(0).brightness(0.25).colorMultiply(Color(hex: c))
        case .pet, .food:
            e
        }
    }

    private var detail: String {
        switch item.thing {
        case .food(let r): "+\(r) roll\(r > 1 ? "s" : "")"
        case .pet: wearing ? "Walking with you" : owned ? "At home" : "Walks with you"
        default: wearing ? "Wearing" : owned ? "In your wardrobe" : " "
        }
    }

    @ViewBuilder private var actions: some View {
        if item.isFood {
            Button("\(item.price) ¢") { model.buyItem(item) }
                .buttonStyle(CardButtonStyle())
                .disabled(model.player.coins < item.price || model.player.foodRollsLeft == 0)
        } else if owned {
            HStack(spacing: 6) {
                Button(wearing ? (item.isPet ? "Home" : "Take off") : (item.isPet ? "Walk" : "Wear")) { model.toggleWear(item) }
                    .buttonStyle(CardButtonStyle())
                Button("Sell \(item.resale) ¢") { model.sellItem(item) }
                    .buttonStyle(CardButtonStyle())
            }
        } else {
            Button("\(item.price) ¢") { model.buyItem(item) }
                .buttonStyle(CardButtonStyle())
                .disabled(model.player.coins < item.price)
        }
    }
}
