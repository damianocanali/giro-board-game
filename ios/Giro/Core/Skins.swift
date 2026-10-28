import Foundation

/// A look for your pawn and die. Colours are 0xRRGGBB.
public struct Skin: Identifiable, Equatable, Sendable {
    public enum Price: Equatable, Sendable {
        case free
        case coins(Int)
        /// Comes with the Giro pass.
        case pass
    }

    public enum Hat: String, Sendable { case none, cap, crown, topHat, flower }

    public var id: String
    public var name: String
    public var price: Price
    public var pawn: UInt32
    public var die: UInt32
    public var pips: UInt32
    /// Colour of the single pip on the 1 face.
    public var onePip: UInt32
    public var hat: Hat
    public var hatColor: UInt32

    public static let classic = Skin(id: "classic", name: "Classic", price: .free,
                                     pawn: 0xF5B700, die: 0xFFFDF8, pips: 0x2B1A10, onePip: 0xE5533D, hat: .none, hatColor: 0)
    public static let gold = Skin(id: "gold", name: "Golden", price: .pass,
                                  pawn: 0xE0A100, die: 0xF2C94C, pips: 0x6B4300, onePip: 0xFFFFFF, hat: .crown, hatColor: 0xFFD54A)

    public static let all: [Skin] = [
        classic,
        Skin(id: "mint", name: "Mint", price: .coins(400),
             pawn: 0x6FD3B8, die: 0xE3F7F0, pips: 0x1E6B5A, onePip: 0x1E6B5A, hat: .cap, hatColor: 0x2E8B74),
        Skin(id: "tomato", name: "Tomato", price: .coins(400),
             pawn: 0xF26B4A, die: 0xFFFDF8, pips: 0xC23B22, onePip: 0xC23B22, hat: .flower, hatColor: 0x5DBB63),
        Skin(id: "bubblegum", name: "Bubblegum", price: .coins(600),
             pawn: 0xFF9EC7, die: 0xFFE3F0, pips: 0xB0306A, onePip: 0xB0306A, hat: .flower, hatColor: 0xFFFFFF),
        Skin(id: "midnight", name: "Midnight", price: .coins(900),
             pawn: 0x34406B, die: 0x2B3352, pips: 0xFFFFFF, onePip: 0xF5B700, hat: .topHat, hatColor: 0x1A1F33),
        gold,
    ]

    public static func named(_ id: String) -> Skin { all.first { $0.id == id } ?? classic }
}
