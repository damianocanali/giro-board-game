import SwiftUI

/// The title menu shown at launch, over the slowly turning city.
struct MenuView: View {
    let model: GameModel
    @State private var showHowTo = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                Text("Rollabout")
                    .font(Theme.display(68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
                    .foregroundStyle(Theme.ink)
                    .shadow(color: Theme.sheet.opacity(0.9), radius: 0, y: 4)
                Text("The city is the board.")
                    .font(Theme.body(19, .bold))
                    .foregroundStyle(Theme.ink2)
                Button { model.showCityPicker = true } label: {
                    Label(model.player.homeCity ?? "Choose your city", systemImage: "mappin.and.ellipse")
                        .font(Theme.body(15, .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.youSoft, in: Capsule())
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 28).padding(.vertical, 22)
            .background(Theme.sheet.opacity(0.92), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.18), radius: 18, y: 10)
            

            Spacer()

            VStack(spacing: 12) {
                if showHowTo { HowToCard().transition(.move(edge: .bottom).combined(with: .opacity)) }
                Button { model.play() } label: {
                    Text(model.hasSave ? "CONTINUE" : "PLAY")
                        .font(Theme.display(30))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 68)
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.button, shadow: Theme.buttonShadow))
                HStack(spacing: 8) {
                    Button(showHowTo ? "Hide rules" : "How to play") {
                        withAnimation(.spring(duration: 0.35)) { showHowTo.toggle() }
                    }
                    .buttonStyle(MenuChip())
                    Button { model.showSkins = true } label: { Label("Skins", systemImage: "tshirt.fill") }
                        .buttonStyle(MenuChip())
                    Button { model.musicOn.toggle() } label: {
                        Image(systemName: model.musicOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .frame(width: 22)
                    }
                    .buttonStyle(MenuChip())
                    .accessibilityLabel(model.musicOn ? "Turn music off" : "Turn music on")
                }
            }
            .frame(maxWidth: 380)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Theme.paper.opacity(0.0), Theme.paper.opacity(0.55)], startPoint: .center, endPoint: .bottom).ignoresSafeArea())
    }
}

private struct MenuChip: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(16, .heavy))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.sheet.opacity(configuration.isPressed ? 0.7 : 0.92), in: Capsule())
    }
}

private struct HowToCard: View {
    private let rows: [(String, String)] = [
        ("die.face.5.fill", "Roll the die and drive through other players' blocks."),
        ("square.fill", "Each street square does what the building beside it does: coins, a free roll, a duel or a bus ride."),
        ("arrow.triangle.branch", "At a fork, choose which way to go."),
        ("hammer.fill", "Earn coins, buy land and build your own block."),
        ("moon.stars.fill", "You get \(GameConfig.dailyRolls) free rolls every day. They come back at midnight."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows, id: \.1) { icon, text in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: icon).foregroundStyle(Theme.button).frame(width: 22)
                    Text(text).font(Theme.body(15)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.15), radius: 12, y: 6)
    }
}
