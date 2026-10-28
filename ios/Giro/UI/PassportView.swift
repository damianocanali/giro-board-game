import SwiftUI
import UIKit

/// The new-stamp ceremony: the passport pops out, opens, and a stamp with the city's name slams onto the page.
struct PassportStampView: View {
    let model: GameModel
    let event: StampEvent

    @State private var shown = false
    @State private var open = false
    @State private var stamped = false
    @State private var shake = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.35 : 0).ignoresSafeArea()
                .onTapGesture { if stamped { model.dismissStamp() } }

            VStack(spacing: 18) {
                book
                    .scaleEffect(shown ? 1 : 0.2)
                    .rotation3DEffect(.degrees(shown ? 14 : 70), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(shown ? -6 : -40), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .offset(x: shake ? 4 : 0, y: shake ? 3 : 0)
                    .shadow(color: .black.opacity(0.35), radius: 22, y: 16)

                VStack(spacing: 6) {
                    Text("New stamp!").font(Theme.display(30)).foregroundStyle(Theme.sheet)
                    Text("\(event.owner)'s block in \(event.city) · +\(event.coins) coins")
                        .font(Theme.body(15, .bold)).foregroundStyle(Theme.sheet.opacity(0.9))
                        .multilineTextAlignment(.center)
                    Button { model.dismissStamp() } label: {
                        Text("Nice!")
                            .font(Theme.display(20))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 40).frame(minHeight: 52)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.button, shadow: Theme.buttonShadow))
                        .padding(.top, 6)
                }
                .opacity(stamped ? 1 : 0)
                .offset(y: stamped ? 0 : 20)
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("New passport stamp: \(event.city)")
        .task { await play() }
    }

    private func play() async {
        model.sfx.play(.whoosh, volume: 0.7)
        withAnimation(.spring(duration: 0.55, bounce: 0.35)) { shown = true }
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.easeInOut(duration: 0.55)) { open = true }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring(duration: 0.22, bounce: 0.1)) { stamped = true }
        try? await Task.sleep(for: .milliseconds(150))
        model.sfx.play(.stamp)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.linear(duration: 0.05).repeatCount(3, autoreverses: true)) { shake = true }
        try? await Task.sleep(for: .milliseconds(160))
        shake = false
        try? await Task.sleep(for: .milliseconds(250))
        model.sfx.play(.achievement, volume: 0.5)
    }

    // MARK: Book

    private let pageW: CGFloat = 165, pageH: CGFloat = 220

    private var book: some View {
        HStack(spacing: 0) {
            // Left page: the inside of the cover once it has swung open.
            ZStack {
                if open { leftPage.transition(.opacity) }
            }
            .frame(width: pageW, height: pageH)

            ZStack {
                rightPage
                cover
                    .rotation3DEffect(.degrees(open ? -180 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
            }
            .frame(width: pageW, height: pageH)
        }
    }

    private var cover: some View {
        // Hide the front once it has turned past the spine, so the back shows the inside page.
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: 0x1F3A5F))
            VStack(spacing: 14) {
                Text("PASSPORT").font(Theme.body(15, .heavy)).tracking(3)
                Image(systemName: "globe.europe.africa.fill").font(.system(size: 54))
                Text("GIRO").font(Theme.display(22)).tracking(4)
            }
            .foregroundStyle(Color(hex: 0xE8C468))
        }
        .opacity(open ? 0 : 1)
        .animation(.easeInOut(duration: 0.01).delay(open ? 0.27 : 0), value: open)
    }

    private var leftPage: some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10, style: .continuous).fill(Color(hex: 0xF6EEDC))
            VStack(alignment: .leading, spacing: 8) {
                Text("STAMPS").font(Theme.body(11, .heavy)).tracking(2).foregroundStyle(Theme.ink2)
                let others = earlierCities
                if others.isEmpty {
                    Text("Your first stamp!").font(Theme.body(13, .bold)).foregroundStyle(Theme.ink2)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(others.prefix(6), id: \.self) { c in
                            StampMark(city: c, date: nil, small: true).opacity(0.75)
                        }
                    }
                }
                Spacer(minLength: 0)
                Text("No. \(event.number)").font(Theme.mono(12)).foregroundStyle(Theme.ink2)
            }
            .padding(12)
        }
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 2) }
    }

    private var rightPage: some View {
        ZStack {
            UnevenRoundedRectangle(bottomTrailingRadius: 10, topTrailingRadius: 10, style: .continuous).fill(Color(hex: 0xFBF5E8))
            // Faint guilloche lines like a real passport page.
            VStack(spacing: 9) { ForEach(0..<20, id: \.self) { _ in Rectangle().fill(Color(hex: 0xE9DFC8)).frame(height: 1) } }
                .padding(.horizontal, 10).clipped()
            StampMark(city: event.city, date: event.date, small: false)
                .rotationEffect(.degrees(-9))
                .scaleEffect(stamped ? 1 : 2.6)
                .opacity(stamped ? 1 : 0)
        }
    }

    private var earlierCities: [String] {
        model.player.stamps.sorted().map { model.map.owners[$0].city }.filter { $0 != event.city && !$0.isEmpty }
    }
}

/// An ink stamp: double border, the city in big letters, GIRO and the date.
struct StampMark: View {
    var city: String
    var date: Date?
    var small: Bool

    private var ink: Color {
        let inks: [UInt32] = [0xC0392B, 0x1F5FA8, 0x2E7D4F, 0x7B3FA0, 0xB5651D]
        let h = city.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Color(hex: inks[h % inks.count])
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: small ? 6 : 12, style: .continuous)
        VStack(spacing: small ? 1 : 4) {
            if !small {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                    Text("GIRO").tracking(3)
                    Image(systemName: "star.fill")
                }
                .font(.system(size: 10, weight: .heavy, design: .rounded))
            }
            Text(city.uppercased())
                .font(.system(size: small ? 10 : 24, weight: .black, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.5)
            if let date {
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, small ? 6 : 14).padding(.vertical, small ? 5 : 10)
        .frame(maxWidth: small ? .infinity : 140)
        .overlay(shape.stroke(ink, lineWidth: small ? 1.5 : 3))
        .overlay(shape.inset(by: small ? 3 : 5).stroke(ink, lineWidth: small ? 0.8 : 1.5))
        .opacity(0.9)
    }
}

/// Pick the city you play for. Each city has its own monuments.
struct CityPickerSheet: View {
    let model: GameModel
    private let flags = ["New York": "🇺🇸", "Roma": "🇮🇹", "Paris": "🇫🇷", "London": "🇬🇧", "Tokyo": "🇯🇵", "Cairo": "🇪🇬"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Tile.homeCities, id: \.city) { entry in
                        Button { model.chooseCity(entry.city) } label: {
                            HStack(spacing: 12) {
                                Text(flags[entry.city] ?? "🏙️").font(.system(size: 30))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.city).font(Theme.body(17, .heavy))
                                    Text(entry.monuments.map(\.name).joined(separator: " · "))
                                        .font(Theme.body(13)).foregroundStyle(Theme.ink2)
                                }
                                Spacer()
                                if model.player.homeCity == entry.city {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good)
                                }
                            }
                            .foregroundStyle(Theme.ink)
                        }
                    }
                } footer: {
                    Text("Your city decides which monuments you can build. You can change it later.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Your city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.showCityPicker = false } } }
        }
        .tint(Theme.ink)
    }
}
