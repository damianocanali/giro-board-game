import SwiftUI

/// Inside a building, over the 3D room: the shopkeeper's hello at the top and the goods on a panel below.
/// At home the panel is your wardrobe instead.
struct InteriorHUD: View {
    let model: GameModel
    let visit: StoreVisit

    private var isHome: Bool { visit.kind == .home }
    private var items: [StoreItem] {
        isHome ? StoreItem.catalog.filter { !$0.isFood && model.player.owns($0) } : visit.kind.items
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            if !isHome {
                Text(greeting)
                    .font(Theme.body(15, .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    .shadow(color: Theme.ink.opacity(0.15), radius: 8, y: 4)
                    .transition(.scale.combined(with: .opacity))
            }
            panel
        }
    }

    private var greeting: String {
        if visit.owner == "Your" { return "Welcome back, boss! Business is good." }
        let name = visit.owner.hasSuffix("'s") ? String(visit.owner.dropLast(2)) : visit.owner
        return "Hi, I'm \(name)! Welcome to my \(visit.kind.name.lowercased()) in \(visit.city)."
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isHome ? "Your wardrobe" : "\(visit.owner) \(visit.kind.name.lowercased())")
                    .font(Theme.display(22)).foregroundStyle(Theme.ink)
                Spacer()
                Button { model.leaveStore() } label: {
                    Label("Leave", systemImage: "door.left.hand.open").font(Theme.body(14, .bold))
                }
                .buttonStyle(CardButtonStyle())
            }
            if visit.kind == .cafe || visit.kind == .grocery { energy }
            if items.isEmpty {
                Text("Clothes, shoes and pets you buy in shops end up here, ready to wear.")
                    .font(Theme.body(14)).foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in StoreItemCard(model: model, item: item, canSell: !isHome).frame(width: 150) }
                    }
                }
            }
            if !isHome && visit.kind != .cafe && visit.kind != .grocery {
                Text("Shops buy back anything you own for half what you paid.")
                    .font(Theme.body(12)).foregroundStyle(Theme.ink2)
            }
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.18), radius: 14, y: 6)
        .frame(maxWidth: 520)
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
            if visit.kind == .cafe && !model.player.freeSnackTaken {
                Button("Free daily snack: +\(StoreItem.freeSnackRolls) roll") { model.takeFreeSnack() }
                    .buttonStyle(CardButtonStyle())
                    .disabled(model.player.foodRollsLeft < StoreItem.freeSnackRolls)
            }
        }
        .padding(12)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Walking through a door: the screen fades to paper with a spinner.
struct DoorFade: View {
    let text: String

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(Theme.ink)
                Text(text).font(Theme.body(17, .bold)).foregroundStyle(Theme.ink)
            }
        }
    }
}

struct StoreItemCard: View {
    let model: GameModel
    let item: StoreItem
    var canSell = true

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
                if canSell {
                    Button("Sell \(item.resale) ¢") { model.sellItem(item) }
                        .buttonStyle(CardButtonStyle())
                }
            }
        } else {
            Button("\(item.price) ¢") { model.buyItem(item) }
                .buttonStyle(CardButtonStyle())
                .disabled(model.player.coins < item.price)
        }
    }
}
