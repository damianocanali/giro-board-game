import SwiftUI

struct ShopSheet: View {
    let model: GameModel

    var body: some View {
        NavigationStack {
            List {
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
                    Text(ShopItem.crateOddsText + ". Demo store: nothing is charged.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.showShop = false } } }
        }
        .tint(Theme.ink)
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
                    ForEach([CityMap.SquareKind.shop, .office, .school, .park, .plaza, .busStop, .home, .forSale], id: \.self) { k in
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
