import Foundation

/// What your character wears. The skin colours the body; clothes and shoes go on top of it. Colours are 0xRRGGBB.
public struct Outfit: Codable, Equatable, Hashable, Sendable {
    public enum Top: String, Codable, CaseIterable, Sendable { case none, tee, hoodie, jacket, dress }
    public enum Bottom: String, Codable, CaseIterable, Sendable { case none, shorts, trousers, skirt }
    public enum Shoes: String, Codable, CaseIterable, Sendable { case none, sneakers, boots, sandals }

    public var top: Top
    public var topColor: UInt32
    public var bottom: Bottom
    public var bottomColor: UInt32
    public var shoes: Shoes
    public var shoeColor: UInt32

    public init(top: Top = .none, topColor: UInt32 = 0xFFFFFF, bottom: Bottom = .none, bottomColor: UInt32 = 0x4A6FA5,
                shoes: Shoes = .sneakers, shoeColor: UInt32 = 0xE5533D) {
        self.top = top; self.topColor = topColor
        self.bottom = bottom; self.bottomColor = bottomColor
        self.shoes = shoes; self.shoeColor = shoeColor
    }

    /// What a new player starts in: just a pair of sneakers.
    public static let starter = Outfit()

    /// A dress covers the legs, so it is never worn with a bottom.
    public var normalized: Outfit {
        var o = self
        if o.top == .dress { o.bottom = .none }
        return o
    }

    /// A varied but stable outfit for another player, picked from their id.
    public static func sample(_ seed: Int) -> Outfit {
        let colors: [UInt32] = [0xFFFFFF, 0x4A90D9, 0xE5533D, 0x5DBB63, 0xF5C542, 0x6B4A9E, 0x2F3E4E, 0xF28C28, 0xFF9EC7]
        let s = abs(seed)
        let tops: [Top] = [.tee, .hoodie, .jacket, .dress, .tee]
        let bottoms: [Bottom] = [.trousers, .shorts, .skirt, .trousers]
        let shoes: [Shoes] = [.sneakers, .boots, .sandals, .sneakers]
        return Outfit(top: tops[s % tops.count], topColor: colors[(s * 3 + 1) % colors.count],
                      bottom: bottoms[(s / 2) % bottoms.count], bottomColor: colors[(s * 5 + 6) % colors.count],
                      shoes: shoes[(s / 3) % shoes.count], shoeColor: colors[(s * 7 + 2) % colors.count]).normalized
    }
}
