import SwiftUI

/// Build mode: the tool tray and the "open to the city" bar. Replaces the ROLL dock.
struct BuildPanel: View {
    let model: GameModel

    var body: some View {
        VStack(spacing: 10) {
            if let d = model.draft { StatusCard(model: model, draft: d) }
            ToolTray(model: model)
        }
        .frame(maxWidth: 520)
    }
}

private struct StatusCard: View {
    let model: GameModel
    let draft: BuildDraft

    var body: some View {
        let issues = draft.issues
        let affordable = model.player.coins >= draft.cost
        VStack(alignment: .leading, spacing: 8) {
            if model.isUpgrading {
                Line(icon: "arrow.up.circle.fill", color: Theme.coin,
                     text: "Tap one of your buildings to raise it a level. Each level pays visitors 50% more.")
            } else if !draft.hasChanges {
                Line(icon: "hand.tap.fill", color: Theme.ink2,
                     text: "Tap a square on your land. Yellow pads with a + are free; buildings need a street next to them.")
            } else if issues.isEmpty {
                Line(icon: "checkmark.circle.fill", color: Theme.good,
                     text: "All streets connect and every building is on a street." + (draft.cost > 0 ? " This costs \(draft.cost) coins." : ""))
            }
            if !issues.brokenEdges.isEmpty {
                Line(icon: "exclamationmark.octagon.fill", color: Theme.bad,
                     text: "\(issues.brokenEdges.count) border \(plural(issues.brokenEdges.count, "street doesn't", "streets don't")) meet a neighbour's street (red discs).")
            }
            if !issues.disconnected.isEmpty {
                Line(icon: "exclamationmark.triangle.fill", color: Theme.warn,
                     text: "\(issues.disconnected.count) \(plural(issues.disconnected.count, "street isn't", "streets aren't")) joined to the city (orange discs).")
            }
            if !issues.unreachable.isEmpty {
                Line(icon: "exclamationmark.octagon.fill", color: Theme.bad,
                     text: "\(issues.unreachable.count) \(plural(issues.unreachable.count, "building has", "buildings have")) no street next to \(issues.unreachable.count == 1 ? "it" : "them") (red rings).")
            }
            if draft.hasChanges, let after = model.draftNeeds {
                HappinessLine(before: model.needs.happiness, after: after.happiness)
            }
            if draft.hasChanges && !affordable {
                Line(icon: "circle.fill", color: Theme.coin, text: "You need \(draft.cost - model.player.coins) more coins to open this.")
            }
            if !issues.isEmpty {
                Button { model.removeProblems() } label: {
                    Label("Remove what can't stay", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CardButtonStyle())
                .accessibilityHint("Clears only the squares with a problem and keeps the rest of your changes")
            }
            HStack(spacing: 8) {
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(CardButtonStyle(filled: false))
                    .disabled(!draft.canUndo)
                    .accessibilityLabel("Undo")
                Button("Discard all") { model.discardDraft() }
                    .buttonStyle(CardButtonStyle(filled: false))
                    .disabled(!draft.hasChanges)
                Button(draft.cost > 0 ? "Open to the city · \(draft.cost)¢" : "Open to the city") { model.openToCity() }
                    .buttonStyle(CardButtonStyle())
                    .disabled(!draft.canOpen || !affordable)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.18), radius: 14, y: 6)
    }

    private func plural(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? one : many }
}

private struct Line: View {
    var icon: String
    var color: Color
    var text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 13, weight: .bold))
            Text(text).font(Theme.body(14)).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HappinessLine: View {
    var before: Double
    var after: Double
    var body: some View {
        let b = Int((before * 100).rounded()), a = Int((after * 100).rounded())
        let color = a > b ? Theme.good : a < b ? Theme.bad : Theme.ink2
        HStack(spacing: 8) {
            Image(systemName: "face.smiling.inverse").foregroundStyle(color).font(.system(size: 13, weight: .bold))
            Text("Block happiness \(b)%").font(Theme.body(14))
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.ink2)
            Text("\(a)%").font(Theme.body(14, .heavy)).foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Block happiness goes from \(b) to \(a) percent")
    }
}

private struct ToolTray: View {
    let model: GameModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(BuildDraft.tools.enumerated()), id: \.element) { i, t in
                    chip(t)
                    if i == 0 { upgradeChip }
                }
                Rectangle().fill(Theme.line).frame(width: 2, height: 60).padding(.horizontal, 2)
                if model.player.homeCity == nil {
                    Button { model.showCityPicker = true } label: {
                        ToolLabel(icon: "building.columns.fill", title: "Monuments", subtitle: "pick city", selected: false, tint: Theme.ink)
                    }
                    .accessibilityLabel("Choose your city to build its monuments")
                } else {
                    ForEach(Tile.monuments(in: model.player.homeCity), id: \.self) { chip($0) }
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 4)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private var upgradeChip: some View {
        Button { model.isUpgrading = true } label: {
            ToolLabel(icon: "arrow.up.circle.fill", title: "Upgrade", subtitle: "level up", selected: model.isUpgrading, tint: Theme.coin)
        }
        .accessibilityLabel("Upgrade a building")
        .accessibilityAddTraits(model.isUpgrading ? .isSelected : [])
    }

    private func chip(_ t: Tile) -> some View {
        let selected = !model.isUpgrading && model.buildTool == t
        return Button { model.buildTool = t; model.isUpgrading = false } label: {
            if t == .empty {
                ToolLabel(icon: "trash.fill", title: "Remove", subtitle: "free", selected: selected, tint: Theme.bad)
            } else if t.isMonument {
                ToolLabel(icon: "building.columns.fill", title: t.name, subtitle: "\(t.cost)¢", selected: selected, tint: Color(hex: 0x9B6FD6))
            } else {
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(hex: t.swatch))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Theme.ink.opacity(0.25), lineWidth: 1))
                        .frame(width: 30, height: 30)
                    Text(t.name).font(Theme.body(12, .bold)).lineLimit(1)
                    Text("\(t.cost)¢").font(Theme.mono(11)).foregroundStyle(Theme.ink2)
                }
                .modifier(ChipFrame(selected: selected))
            }
        }
        .accessibilityLabel("\(t.name), \(t.cost > 0 ? "\(t.cost) coins" : "free")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ToolLabel: View {
    var icon: String
    var title: String
    var subtitle: String
    var selected: Bool
    var tint: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(tint).frame(height: 30)
            Text(title).font(Theme.body(12, .bold)).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            Text(subtitle).font(Theme.mono(11)).foregroundStyle(Theme.ink2)
        }
        .modifier(ChipFrame(selected: selected, wide: title.count > 10))
    }
}

private struct ChipFrame: ViewModifier {
    var selected: Bool
    var wide = false
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Theme.ink)
            .frame(width: wide ? 104 : 74, height: 82)
            .background(selected ? Theme.youSoft : Theme.sheet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selected ? Theme.you : Theme.line, lineWidth: selected ? 3 : 1))
    }
}
