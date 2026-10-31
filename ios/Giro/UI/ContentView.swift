import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()

    var body: some View {
        ZStack {
            CityView(model: model)
                .ignoresSafeArea()

            if model.showMenu {
                MenuView(model: model)
                    .transition(.opacity)
            } else {
            VStack(spacing: 10) {
                TopBar(model: model)
                if let v = model.storeVisit {
                    InteriorHUD(model: model, visit: v)
                } else {
                if !model.isBuilding { StatusRow(model: model) }
                if let t = model.toast {
                    ToastView(toast: t)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(t.id)
                }
                Spacer()
                if !model.forkChoices.isEmpty {
                    ForkPanel(model: model)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if model.isBuilding {
                    BuildPanel(model: model)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    if let v = model.nearbyStore {
                        Button { model.enterNearbyStore() } label: {
                            Label("Go into \(v.owner == "Your" ? "your" : v.owner) \(v.kind.name.lowercased())", systemImage: "door.left.hand.open")
                                .font(Theme.body(15, .bold))
                        }
                        .buttonStyle(CardButtonStyle())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    RollDock(model: model)
                }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.opacity)
            }

            if let v = model.rolledValue {
                Text("\(v)")
                    .font(Theme.display(56))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 96, height: 96)
                    .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.you, lineWidth: 5))
                    .shadow(color: Theme.ink.opacity(0.25), radius: 14, y: 8)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("You rolled \(v)")
            }

            if let d = model.duel {
                Dimmer()
                DuelCard(model: model, duel: d)
            } else if let b = model.saleOffer {
                Dimmer()
                SaleCard(model: model, block: b)
            }

            if let e = model.stampEvent {
                PassportStampView(model: model, event: e)
                    .id(e.id)
                    .transition(.opacity)
            }

            if model.showShop {
                ShopSheet(model: model).transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else if model.showSkins {
                SkinsSheet(model: model).transition(.opacity.combined(with: .scale(scale: 0.94)))
            }

            if let i = model.iris {
                IrisWipe(iris: i)
            }
        }
        .animation(.spring(duration: 0.3), value: model.showShop)
        .animation(.spring(duration: 0.3), value: model.showSkins)
        .animation(.easeInOut(duration: 0.25), value: model.stampEvent)
        .animation(.spring(duration: 0.35), value: model.toast)
        .animation(.spring(duration: 0.3), value: model.rolledValue)
        .animation(.spring(duration: 0.3), value: model.forkChoices)
        .animation(.spring(duration: 0.3), value: model.isBuilding)
        .animation(.spring(duration: 0.3), value: model.nearbyStore)
        .animation(.easeInOut(duration: 0.4), value: model.showMenu)
        .sheet(isPresented: $model.showCityPicker) { CityPickerSheet(model: model).presentationDetents([.medium, .large]) }
        .sheet(isPresented: $model.showMissions) { MissionsSheet(model: model).presentationDetents([.large]) }
        .task { model.start() }
    }
}

// MARK: - Top bar

private struct TopBar: View {
    let model: GameModel

    var body: some View {
        HStack(spacing: 6) {
            Pill {
                Image(systemName: "circle.fill").foregroundStyle(Theme.coin).font(.system(size: 12))
                Text(model.player.coins.formatted()).font(Theme.mono(16))
            }
            .accessibilityLabel("\(model.player.coins) coins")
            Pill {
                Image(systemName: "die.face.5.fill").foregroundStyle(Theme.ink)
                Text("\(model.player.rolls)").font(Theme.mono(16))
            }
            .accessibilityLabel("\(model.player.rolls) rolls")
            Spacer(minLength: 0)
            Menu {
                Section("View") {
                    ForEach(CityScene.CameraView.allCases) { v in
                        Button { model.cameraView = v } label: { Label(v.name, systemImage: model.cameraView == v ? "checkmark" : v.icon) }
                    }
                }
                Section("Camera") {
                    Button { model.scene?.focusOnPawn() } label: { Label("Follow me", systemImage: "figure.walk") }
                    Button { model.scene?.focusOnMyBlocks() } label: { Label("My block", systemImage: "house") }
                    Button { model.scene?.focusOnCity() } label: { Label("Whole city", systemImage: "map") }
                }
                Button { model.showSkins = true } label: { Label("Skins", systemImage: "tshirt") }
                Button { model.showCityPicker = true } label: { Label(model.player.homeCity ?? "Choose your city", systemImage: "mappin.and.ellipse") }
                Toggle(isOn: Binding(get: { model.musicOn }, set: { model.musicOn = $0 })) {
                    Label("Music", systemImage: "music.note")
                }
                Toggle(isOn: Binding(get: { model.soundOn }, set: { model.soundOn = $0 })) {
                    Label("Sound effects", systemImage: "speaker.wave.2")
                }
            } label: { RoundIcon(system: "ellipsis") }
            .accessibilityLabel("Camera, skins, city and sound")
            Button { model.isBuilding ? model.leaveBuild() : model.enterBuild() } label: {
                RoundIcon(system: model.isBuilding ? "xmark" : "hammer.fill", active: model.isBuilding)
            }
            .accessibilityLabel(model.isBuilding ? "Leave build mode" : "Build on your land")
            .disabled(model.isBusy)
            Button { model.showMissions = true } label: { RoundIcon(system: "flag.checkered", badge: Mission.daily.contains { model.player.canClaim($0) }) }
                .accessibilityLabel("Missions and passport")
            Button { model.showShop = true } label: { RoundIcon(system: "bag.fill") }
                .accessibilityLabel("Shop")
        }
        .padding(.top, 4)
    }
}

/// Weather and the running holiday event, under the top bar.
private struct StatusRow: View {
    let model: GameModel

    var body: some View {
        HStack(spacing: 6) {
            Button { model.showToast("Weather: \(model.weather.name)", model.weather.effect, seconds: 3) } label: {
                Pill {
                    Image(systemName: model.weather.symbol).symbolRenderingMode(.multicolor)
                    Text(model.weather.name).font(Theme.body(13, .bold))
                }
            }
            .accessibilityLabel("Weather \(model.weather.name). \(model.weather.effect)")
            if let h = model.holiday {
                Button { model.showShop = true } label: {
                    Pill {
                        Text(h.tokenSymbol)
                        Text("\(h.name) \(min(model.player.eventTokens[h.id] ?? 0, h.goal))/\(h.goal)").font(Theme.body(13, .bold))
                        Text("· \(h.daysLeft(from: model.now))d").font(Theme.body(12)).foregroundStyle(Theme.ink2)
                    }
                }
                .accessibilityLabel("\(h.name) event: \(model.player.eventTokens[h.id] ?? 0) of \(h.goal) collected")
            }
            Spacer(minLength: 0)
        }
    }
}

private struct Pill<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 6) { content }
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.sheet.opacity(0.95), in: Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .shadow(color: Theme.ink.opacity(0.08), radius: 8, y: 4)
    }
}

private struct RoundIcon: View {
    var system: String
    var badge = false
    var active = false
    var body: some View {
        Image(systemName: system)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(width: 44, height: 44)
            .background(active ? Theme.you : Theme.sheet.opacity(0.95), in: Circle())
            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if badge { Circle().fill(Theme.bad).frame(width: 12, height: 12).offset(x: -2, y: 2) }
            }
            .shadow(color: Theme.ink.opacity(0.08), radius: 8, y: 4)
    }
}

private struct ToastView: View {
    let toast: Toast
    var body: some View {
        VStack(spacing: 2) {
            Text(toast.title).font(Theme.body(15, .bold))
            if let d = toast.detail { Text(d).font(Theme.body(13)).opacity(0.8) }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.sheet)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Roll dock and fork chooser

private struct RollDock: View {
    let model: GameModel

    var body: some View {
        if model.player.rolls == 0, let s = model.player.secondsToRefill(now: model.now) {
            OutOfRollsCard(model: model, seconds: s)
        } else {
            dock
        }
    }

    private var dock: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button { Task { await model.roll() } } label: {
                VStack(spacing: 2) {
                    Text("ROLL").font(Theme.display(30))
                    Text(model.player.rolls == 0 ? "Out of rolls" : "\(model.player.rolls) left")
                        .font(Theme.body(12, .bold)).opacity(0.85)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.button, shadow: Theme.buttonShadow))
            .disabled(!model.canRoll)
        }
        .frame(maxWidth: 380)
    }
}

/// Shown instead of the ROLL button once today's rolls are spent.
private struct OutOfRollsCard: View {
    let model: GameModel
    let seconds: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("New rolls in").font(Theme.body(12, .bold)).foregroundStyle(Theme.ink2)
                Text(GameModel.clock(seconds)).font(Theme.mono(28)).foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                Text("\(GameConfig.dailyRolls) free rolls every day at midnight").font(Theme.body(11)).foregroundStyle(Theme.ink2)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button { model.showShop = true } label: {
                Text("Get rolls").font(Theme.display(17)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16).frame(minHeight: 52)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.button, shadow: Theme.buttonShadow))
        }
        .padding(14)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 2))
        .frame(maxWidth: 380)
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var color: Color
    var shadow: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isEnabled ? color : color.opacity(0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(shadow.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 20, style: .continuous).offset(y: configuration.isPressed ? 2 : 6))
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

private struct ForkPanel: View {
    let model: GameModel
    private let colors: [Color] = [Color(hex: 0xE5533D), Color(hex: 0x3E9D4E), Color(hex: 0x4A90D9)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fork in the road. Which way?").font(Theme.body(15, .heavy)).foregroundStyle(Theme.ink)
            ForEach(model.forkChoices) { c in
                Button { model.pickFork(c.id) } label: {
                    HStack(spacing: 10) {
                        Text(["A", "B", "C"][c.id % 3])
                            .font(Theme.display(14)).foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(colors[c.id % 3], in: RoundedRectangle(cornerRadius: 8))
                        Text(c.label).font(Theme.body(15, .bold)).foregroundStyle(Theme.ink)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Theme.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 420)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.2), radius: 16, y: 8)
    }
}

// MARK: - Duel and sale cards

private struct Dimmer: View {
    var body: some View { Color.black.opacity(0.3).ignoresSafeArea().transition(.opacity) }
}

private struct DuelCard: View {
    let model: GameModel
    let duel: DuelState

    var body: some View {
        VStack(spacing: 14) {
            Text("Plaza duel").font(Theme.display(24))
            Text("\(duel.opponent) from \(duel.city) challenges you. Highest die wins \(GameConfig.duelWinCoins) coins. Losing costs nothing.")
                .font(Theme.body(15)).multilineTextAlignment(.center).foregroundStyle(Theme.ink2)
            HStack(spacing: 24) {
                DieFace(value: duel.you, caption: "You", highlight: true)
                Text("vs").font(Theme.display(18))
                DieFace(value: duel.them, caption: duel.opponent, highlight: false)
            }
            if let r = duel.result {
                Text(resultText(r)).font(Theme.body(16, .heavy))
                Button("Continue") { model.finishDuel() }.buttonStyle(CardButtonStyle())
            } else {
                Button("Roll") { model.rollDuel() }.buttonStyle(CardButtonStyle())
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(22)
        .frame(maxWidth: 360)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(24)
    }

    private func resultText(_ r: Rules.DuelResult) -> String {
        switch r {
        case .win(let n): "You win \(n) coins."
        case .tie(let n): "A tie: you both get \(n) coins."
        case .lose: "\(duel.opponent) wins this one."
        }
    }
}

private struct DieFace: View {
    var value: Int?
    var caption: String
    var highlight: Bool
    var body: some View {
        VStack(spacing: 4) {
            Text(value.map { "\($0)" } ?? "?")
                .font(Theme.display(32))
                .frame(width: 64, height: 64)
                .background(highlight ? Theme.youSoft : Theme.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(highlight ? Theme.you : Theme.ink, lineWidth: 2.5))
            Text(caption).font(Theme.body(13)).foregroundStyle(Theme.ink2)
        }
    }
}

private struct SaleCard: View {
    let model: GameModel
    let block: Int

    var body: some View {
        let price = model.map.plotPrices[block] ?? 0
        VStack(spacing: 12) {
            Text("Plot \(block + 1) is for sale").font(Theme.display(22))
            Text("\(price) coins. You have \(model.player.coins).\(block == 11 ? " The bus line runs along it." : "")")
                .font(Theme.body(15)).multilineTextAlignment(.center).foregroundStyle(Theme.ink2)
            HStack(spacing: 10) {
                Button("Not now") { model.answerSale(buy: false) }.buttonStyle(CardButtonStyle(filled: false))
                Button("Buy plot") { model.answerSale(buy: true) }.buttonStyle(CardButtonStyle()).disabled(model.player.coins < price)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(22)
        .frame(maxWidth: 360)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(24)
    }
}

struct CardButtonStyle: ButtonStyle {
    var filled = true
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(16, .heavy))
            .foregroundStyle(filled ? Theme.ink : Theme.ink)
            .padding(.horizontal, 22).padding(.vertical, 12)
            .frame(minWidth: 120)
            .background(filled ? Theme.button.opacity(isEnabled ? 1 : 0.4) : Theme.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
