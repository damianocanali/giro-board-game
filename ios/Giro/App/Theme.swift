import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

/// Warm toy-diorama palette (peach sky, sand blocks, chunky coloured street tiles, yellow "you").
enum Theme {
    // UI
    static let paper = Color(hex: 0xF6D2A6)
    static let sheet = Color(hex: 0xFFF7EC)
    static let ink = Color(hex: 0x4A2E1B)
    static let ink2 = Color(hex: 0x8A6748)
    static let line = Color(hex: 0xE7C9A2)
    static let you = Color(hex: 0xF5B700)
    static let youSoft = Color(hex: 0xFFF0C2)
    static let button = Color(hex: 0xF28C28)
    static let buttonShadow = Color(hex: 0xB85E14)
    static let coin = Color(hex: 0xE0A100)
    static let good = Color(hex: 0x3E9D4E)
    static let warn = Color(hex: 0xE89B1C)
    static let bad = Color(hex: 0xD9483B)

    // Scene
    static let skyHex: UInt32 = 0xF6D2A6
    static let groundHex: UInt32 = 0xEFC795
    static let blockTopHex: UInt32 = 0xF4E4C6
    static let streetHex: UInt32 = 0xCDB596
    static let crossingHex: UInt32 = 0xD8C3A5
    static let sidewalkHex: UInt32 = 0xF7EBD3
    static let laneMarkHex: UInt32 = 0xFFF7EC
    static let youHex: UInt32 = 0xF5B700

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded).monospacedDigit() }
}

extension Tile {
    /// Colour used for swatches.
    var swatch: UInt32 {
        switch self {
        case .road: 0xF0DDBB
        case .house: 0xD9774A
        case .apartments: 0xE08A5C
        case .shop: 0xE5533D
        case .cafe: 0xB8784A
        case .office: 0x4A90D9
        case .school: 0xB49CF0
        case .park: 0x5DBB63
        case .plaza: 0xEDE6DA
        case .busStop: 0x14B8C8
        case .empty: 0xD8E8B8
        default: 0xC9A227
        }
    }
}

extension CityMap.SquareKind {
    /// Colour of the pad on a street square in front of this kind of place.
    /// Everything that pays coins shares one colour so the streets stay calm.
    var tileColor: UInt32 {
        switch self {
        case .home: 0xF5B700
        case .forSale: 0xA9CF6E
        case .shop, .cafe, .office, .school: 0xE89B3C
        case .park: 0x6DBF70
        case .plaza: 0xE36F5A
        case .busStop: 0x3FB4C2
        case .landmark: 0x9B6FD6
        }
    }

    var legend: String {
        switch self {
        case .home: "Your block: +1 roll"
        case .forSale: "For sale: buy land"
        case .shop, .cafe, .office, .school: "Shop, café, office or school: coins"
        case .park: "Park: free roll"
        case .plaza: "Plaza: dice duel"
        case .busStop: "Bus stop: shortcut"
        case .landmark: "Monument: sightseeing coins"
        }
    }
}
