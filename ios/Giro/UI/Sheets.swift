import SwiftUI

/// A card in the middle of the screen over a dimmed game, with a title and a close button.
struct CenterPanel<Content: View>: View {
    let title: String
    let close: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 0) {
                HStack {
                    Text(title).font(Theme.display(26)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34).background(Theme.sheet, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 6)
                content
            }
            .frame(maxWidth: 400, maxHeight: 640)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .shadow(color: Theme.ink.opacity(0.25), radius: 24, y: 10)
            .padding(.horizontal, 16).padding(.vertical, 48)
        }
        .tint(Theme.ink)
    }
}

struct ShopSheet: View {
    let model: GameModel

    var body: some View {
        CenterPanel(title: "Shop", close: { model.showShop = false }) {
            List {
                if let h = model.holiday {
                    Section("\(h.name) · \(h.daysLeft(from: model.now)) days left") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(h.name) pack").font(Theme.body(16, .bold))
                                Text("\(Skin.named(h.packSkin).name) skin, decorations on your block, +\(h.packRolls) rolls")
                                    .font(Theme.body(13)).foregroundStyle(Theme.ink2)
                            }
                            Spacer()
                            if model.player.packs.contains(h.id) {
                                Text("Owned").font(Theme.body(13, .bold)).foregroundStyle(Theme.good)
                            } else {
                                Button(h.packPrice) { model.buyHolidayPack() }.buttonStyle(CardButtonStyle())
                            }
                        }
                        Text("Free for everyone: collect \(h.goal) \(h.tokenSymbol) from street coins to unlock the \(Skin.named(h.rewardSkin).name) skin. You have \(min(model.player.eventTokens[h.id] ?? 0, h.goal)).")
                            .font(Theme.body(13)).foregroundStyle(Theme.ink2)
                    }
                }
                Section {
                    ForEach(ShopItem.catalog) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(Theme.body(16, .bold))
                                Text(item.detail).font(Theme.body(13)).foregroundStyle(Theme.ink2)
                            }
                            Spacer()
                            Button(priceText(item)) { model.purchase(item) }
                                .buttonStyle(CardButtonStyle())
                                .disabled(!affordable(item))
                        }
                    }
                } footer: {
                    Text("Demo store: nothing is charged.")
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func priceText(_ i: ShopItem) -> String {
        switch i.price {
        case .coins(let n): "\(n) ¢"
        case .money(let s): s
        }
    }

    private func affordable(_ i: ShopItem) -> Bool {
        if case .coins(let n) = i.price { return model.player.coins >= n }
        return true
    }
}

struct MissionsSheet: View {
    let model: GameModel
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section("Today's missions") {
                    ForEach(Mission.daily) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(m.title).font(Theme.body(15, .bold))
                                ProgressView(value: Double(model.player.progress(of: m)), total: Double(m.goal)).tint(Theme.you)
                                Text("\(model.player.progress(of: m))/\(m.goal) · reward \(m.rewardRolls) rolls").font(Theme.body(12)).foregroundStyle(Theme.ink2)
                            }
                            Spacer()
                            if model.player.claimed.contains(m.id) {
                                Text("Claimed").font(Theme.body(13)).foregroundStyle(Theme.ink2)
                            } else {
                                Button("Claim") { model.claim(m) }.buttonStyle(CardButtonStyle()).disabled(!model.player.canClaim(m))
                            }
                        }
                    }
                }

                Section("Your land") {
                    let value = model.map.myBlocks.reduce(0) { $0 + model.map.plotValue($1) }
                    HStack {
                        Image(systemName: "map.fill").foregroundStyle(Theme.button)
                        Text("\(model.map.myBlocks.count) plot\(model.map.myBlocks.count == 1 ? "" : "s"), worth about \(value.formatted()) coins")
                            .font(Theme.body(15, .bold))
                    }
                }
                Section("Passport · \(model.player.stamps.count) of \(model.map.ownership.filter { $0 == .other }.count) cities") {
                    let cities = model.map.ownership.indices.filter { model.map.ownership[$0] == .other }
                    FlowLayout(spacing: 6) {
                        ForEach(cities, id: \.self) { b in
                            let got = model.player.stamps.contains(b)
                            Text(model.map.owners[b].city)
                                .font(Theme.body(12, .bold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(got ? Theme.youSoft : Theme.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(got ? Theme.ink : Theme.ink2)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Your block") {
                    LabeledContent("Visits today", value: "\(model.player.visitsToday)")
                    LabeledContent("Coins from visits", value: "\(model.player.earnedToday)")
                    LabeledContent("Residents", value: "\(model.needs.residents)")
                    NeedRow(title: "Jobs", value: model.needs.jobs)
                    NeedRow(title: "Shopping", value: model.needs.shopping)
                    NeedRow(title: "Green space", value: model.needs.green)
                    NeedRow(title: "Bus service", value: model.needs.transit)
                    Text(model.needs.transit < 1
                         ? "Happy blocks earn more per visit. Yours has no bus: buy the plot to the west and put a bus stop next to the bus line."
                         : "Each visit pays ×\(String(format: "%.2f", model.needs.visitMultiplier)).")
                        .font(Theme.body(13)).foregroundStyle(Theme.ink2)
                    ForEach(model.feed, id: \.self) { Text($0).font(Theme.body(13)) }
                }

                Section("Land for sale") {
                    ForEach(model.map.plotPrices.keys.sorted(), id: \.self) { b in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.map.ownership[b] == .mine ? "Your plot" : "Plot \(b + 1)").font(Theme.body(15, .bold))
                                Text(plotDirection(b) + (model.map.ownership[b] == .mine ? "" : " · \(model.map.plotPrices[b] ?? 0) coins"))
                                    .font(Theme.body(12)).foregroundStyle(Theme.ink2)
                            }
                            Spacer()
                            if model.map.ownership[b] == .forSale {
                                Button("Buy") { model.buy(b) }.buttonStyle(CardButtonStyle()).disabled(model.player.coins < (model.map.plotPrices[b] ?? 0))
                            } else {
                                Text("Owned").font(Theme.body(13)).foregroundStyle(Theme.ink2)
                            }
                        }
                    }
                }

                Section("What the squares do") {
                    ForEach([CityMap.SquareKind.shop, .park, .plaza, .busStop, .landmark, .home, .forSale], id: \.self) { k in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 5).fill(Color(hex: k.tileColor)).frame(width: 22, height: 22)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line))
                            Text(k.legend).font(Theme.body(14))
                        }
                    }
                    Text("Gold coins on the street are yours as you drive past. The bet multiplies every reward, but each roll costs that many dice.")
                        .font(Theme.body(12)).foregroundStyle(Theme.ink2)
                }

                Section {
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Your city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.showMissions = false } } }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetProgress() }
            }
        }
        .tint(Theme.ink)
    }

    private func plotDirection(_ b: Int) -> String {
        switch b {
        case 11: "West of you · on the bus line"
        case 13: "East of you"
        case 17: "South of you"
        default: "Nearby"
        }
    }
}

private struct NeedRow: View {
    var title: String
    var value: Double
    var body: some View {
        HStack {
            Text(title).font(Theme.body(14)).frame(width: 100, alignment: .leading)
            ProgressView(value: value).tint(value > 0.75 ? Theme.good : value > 0.45 ? Theme.warn : Theme.bad)
            Text("\(Int((value * 100).rounded()))%").font(Theme.mono(12)).foregroundStyle(Theme.ink2).frame(width: 44, alignment: .trailing)
        }
    }
}

/// Simple wrapping layout for passport stamps.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

struct SkinsSheet: View {
    let model: GameModel
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        CenterPanel(title: "Skins", close: { model.showSkins = false }) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Skin.all) { s in SkinCard(model: model, skin: s) }
                }
                .padding(16)
            }
        }
    }
}

private struct SkinCard: View {
    let model: GameModel
    let skin: Skin

    private var owned: Bool { model.player.owns(skin) }
    private var wearing: Bool { model.player.skinID == skin.id }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                // Pawn: body and head
                VStack(spacing: -4) {
                    Circle().fill(Color(hex: skin.pawn)).frame(width: 26, height: 26)
                    Capsule().fill(Color(hex: skin.pawn)).frame(width: 34, height: 40)
                }
                .overlay(alignment: .top) { hat.offset(y: -10) }
                // Die showing five
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: skin.die))
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    .overlay(pips)
            }
            .frame(height: 84)
            Text(skin.name).font(Theme.body(16, .heavy)).foregroundStyle(Theme.ink)
            action
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(wearing ? Theme.you : Theme.line, lineWidth: wearing ? 3 : 1))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var action: some View {
        if wearing {
            Text("Wearing").font(Theme.body(13, .bold)).foregroundStyle(Theme.good).frame(minHeight: 32)
        } else if owned {
            Button("Wear") { model.equipSkin(skin) }.buttonStyle(CardButtonStyle())
        } else {
            switch skin.price {
            case .coins(let n):
                Button("\(n) ¢") { model.buySkin(skin) }
                    .buttonStyle(CardButtonStyle())
                    .disabled(model.player.coins < n)
            case .pass:
                Button("With Rollabout pass") { model.showSkins = false; model.showShop = true }
                    .buttonStyle(CardButtonStyle())
            case .free:
                EmptyView()
            case .event(let id):
                let h = Holiday.all.first { $0.id == id }
                Text(h.map { "\(min(model.player.eventTokens[$0.id] ?? 0, $0.goal))/\($0.goal) \($0.tokenSymbol) in \($0.name)" } ?? "Event")
                    .font(Theme.body(12, .bold)).foregroundStyle(Theme.ink2).frame(minHeight: 32)
                    .multilineTextAlignment(.center)
            case .pack(let id):
                let h = Holiday.all.first { $0.id == id }
                if let h, model.holiday?.id == id {
                    Button("\(h.name) pack") { model.showSkins = false; model.showShop = true }
                        .buttonStyle(CardButtonStyle())
                } else {
                    Text("\(h?.name ?? "Holiday") pack").font(Theme.body(12, .bold)).foregroundStyle(Theme.ink2).frame(minHeight: 32)
                }
            }
        }
    }

    private var pips: some View {
        let c = Color(hex: skin.pips)
        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(c).frame(width: 8, height: 8)
                    .offset(x: i % 2 == 0 ? -12 : 12, y: i < 2 ? -12 : 12)
            }
            Circle().fill(c).frame(width: 8, height: 8)
        }
    }

    @ViewBuilder private var hat: some View {
        let c = Color(hex: skin.hatColor)
        switch skin.hat {
        case .none: EmptyView()
        case .cap: Capsule().fill(c).frame(width: 30, height: 12)
        case .crown: Image(systemName: "crown.fill").foregroundStyle(c).font(.system(size: 18))
        case .topHat: Rectangle().fill(c).frame(width: 20, height: 16)
        case .flower: Image(systemName: "camera.macro").foregroundStyle(c).font(.system(size: 14))
        case .witch, .santa: Image(systemName: "triangle.fill").foregroundStyle(c).font(.system(size: 18))
        }
    }
}
