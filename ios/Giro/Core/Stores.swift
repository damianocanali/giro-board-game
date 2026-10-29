import Foundation

/// The kinds of store you can walk into. Shops are split between clothes, shoes, pets and groceries; cafés sell snacks.
public enum StoreKind: String, CaseIterable, Sendable {
    case clothes, shoes, pets, grocery, cafe

    public var name: String {
        switch self {
        case .clothes: "Clothing store"
        case .shoes: "Shoe store"
        case .pets: "Pet shop"
        case .grocery: "Grocery"
        case .cafe: "Café"
        }
    }

    /// Which store a building is. Every shop keeps the same kind, picked from where it stands.
    public static func of(_ tile: Tile, at c: Cell) -> StoreKind? {
        switch tile {
        case .cafe: return .cafe
        case .shop:
            let kinds: [StoreKind] = [.clothes, .shoes, .pets, .grocery]
            // Knuth's multiplicative hash; the high bits are well mixed even for neighbouring cells.
            let h = UInt32(truncatingIfNeeded: c.x &* 64 &+ c.y) &* 2_654_435_761
            return kinds[Int(h >> 16) % kinds.count]
        default: return nil
        }
    }

    public var items: [StoreItem] { StoreItem.catalog.filter { $0.store == self } }
}

public enum PetKind: String, Codable, CaseIterable, Sendable { case dog, cat, bunny, duck }

/// Something you can buy in a store. Wearables and pets are kept; food is eaten straight away.
public struct StoreItem: Identifiable, Equatable, Sendable {
    public enum Thing: Equatable, Sendable {
        case top(Outfit.Top, UInt32)
        case bottom(Outfit.Bottom, UInt32)
        case shoes(Outfit.Shoes, UInt32)
        case pet(PetKind, UInt32)
        /// Food gives rolls: energy for more walking.
        case food(rolls: Int)
    }

    public var id: String
    public var name: String
    public var emoji: String
    public var price: Int
    public var store: StoreKind
    public var thing: Thing

    public var isFood: Bool { if case .food = thing { true } else { false } }
    public var isPet: Bool { if case .pet = thing { true } else { false } }
    /// Shops buy things back for half what you paid.
    public var resale: Int { price / 2 }

    public static let catalog: [StoreItem] = [
        StoreItem(id: "tee-white", name: "White tee", emoji: "👕", price: 120, store: .clothes, thing: .top(.tee, 0xFFFFFF)),
        StoreItem(id: "tee-red", name: "Red tee", emoji: "👕", price: 120, store: .clothes, thing: .top(.tee, 0xE5533D)),
        StoreItem(id: "hoodie-blue", name: "Blue hoodie", emoji: "🧥", price: 260, store: .clothes, thing: .top(.hoodie, 0x4A90D9)),
        StoreItem(id: "hoodie-green", name: "Green hoodie", emoji: "🧥", price: 260, store: .clothes, thing: .top(.hoodie, 0x5DBB63)),
        StoreItem(id: "jacket-navy", name: "Navy jacket", emoji: "🧥", price: 380, store: .clothes, thing: .top(.jacket, 0x2F3E4E)),
        StoreItem(id: "dress-yellow", name: "Sunny dress", emoji: "👗", price: 340, store: .clothes, thing: .top(.dress, 0xF5C542)),
        StoreItem(id: "dress-pink", name: "Pink dress", emoji: "👗", price: 340, store: .clothes, thing: .top(.dress, 0xFF9EC7)),
        StoreItem(id: "jeans", name: "Jeans", emoji: "👖", price: 200, store: .clothes, thing: .bottom(.trousers, 0x4A6FA5)),
        StoreItem(id: "chinos", name: "Chinos", emoji: "👖", price: 200, store: .clothes, thing: .bottom(.trousers, 0xC8A878)),
        StoreItem(id: "shorts-orange", name: "Orange shorts", emoji: "🩳", price: 140, store: .clothes, thing: .bottom(.shorts, 0xF28C28)),
        StoreItem(id: "skirt-purple", name: "Purple skirt", emoji: "👗", price: 180, store: .clothes, thing: .bottom(.skirt, 0x6B4A9E)),

        StoreItem(id: "sneakers-white", name: "White sneakers", emoji: "👟", price: 150, store: .shoes, thing: .shoes(.sneakers, 0xFFFFFF)),
        StoreItem(id: "sneakers-blue", name: "Blue sneakers", emoji: "👟", price: 150, store: .shoes, thing: .shoes(.sneakers, 0x4A90D9)),
        StoreItem(id: "boots-brown", name: "Brown boots", emoji: "🥾", price: 280, store: .shoes, thing: .shoes(.boots, 0x8A5A3B)),
        StoreItem(id: "boots-black", name: "Black boots", emoji: "🥾", price: 280, store: .shoes, thing: .shoes(.boots, 0x2B2B2B)),
        StoreItem(id: "sandals", name: "Sandals", emoji: "🩴", price: 90, store: .shoes, thing: .shoes(.sandals, 0xB8784A)),

        StoreItem(id: "pet-dog", name: "Puppy", emoji: "🐶", price: 900, store: .pets, thing: .pet(.dog, 0xC8915A)),
        StoreItem(id: "pet-cat", name: "Kitten", emoji: "🐱", price: 800, store: .pets, thing: .pet(.cat, 0x9A9A9A)),
        StoreItem(id: "pet-bunny", name: "Bunny", emoji: "🐰", price: 700, store: .pets, thing: .pet(.bunny, 0xFFFFFF)),
        StoreItem(id: "pet-duck", name: "Duckling", emoji: "🐥", price: 500, store: .pets, thing: .pet(.duck, 0xF5D142)),

        StoreItem(id: "apple", name: "Apple", emoji: "🍎", price: 40, store: .grocery, thing: .food(rolls: 1)),
        StoreItem(id: "sandwich", name: "Sandwich", emoji: "🥪", price: 90, store: .grocery, thing: .food(rolls: 2)),
        StoreItem(id: "picnic", name: "Picnic basket", emoji: "🧺", price: 200, store: .grocery, thing: .food(rolls: 4)),
        StoreItem(id: "croissant", name: "Croissant", emoji: "🥐", price: 50, store: .cafe, thing: .food(rolls: 1)),
        StoreItem(id: "cappuccino", name: "Cappuccino", emoji: "☕️", price: 70, store: .cafe, thing: .food(rolls: 1)),
        StoreItem(id: "cake", name: "Slice of cake", emoji: "🍰", price: 110, store: .cafe, thing: .food(rolls: 2)),
    ]

    public static func named(_ id: String) -> StoreItem? { catalog.first { $0.id == id } }

    /// Food can give at most this many rolls a day, so coins can't buy endless walking.
    public static let dailyFoodRolls = 6
    /// The first snack at a café each day is free.
    public static let freeSnackRolls = 1
}

extension PlayerState {
    public enum StoreResult: Equatable, Sendable { case ok, tooExpensive, alreadyOwned, full }

    public func owns(_ item: StoreItem) -> Bool { items.contains(item.id) }

    public func isWearing(_ item: StoreItem) -> Bool {
        switch item.thing {
        case .top(let t, let c): outfit.top == t && outfit.topColor == c
        case .bottom(let b, let c): outfit.bottom == b && outfit.bottomColor == c
        case .shoes(let s, let c): outfit.shoes == s && outfit.shoeColor == c
        case .pet: pet == item.id
        case .food: false
        }
    }

    /// Rolls food can still give today.
    public var foodRollsLeft: Int { max(0, StoreItem.dailyFoodRolls - foodRollsToday) }

    /// Pay for an item. Food is eaten at once; clothes, shoes and pets are kept and put on.
    public mutating func buy(_ item: StoreItem) -> StoreResult {
        if case .food(let r) = item.thing, foodRollsLeft < r { return .full }
        if !item.isFood && owns(item) { return .alreadyOwned }
        guard coins >= item.price else { return .tooExpensive }
        coins -= item.price
        if case .food(let r) = item.thing {
            rolls += r
            foodRollsToday += r
        } else {
            items.insert(item.id)
            wear(item)
        }
        return .ok
    }

    /// Put on something you own (or walk a pet you own). Wearing a dress takes off the bottom.
    public mutating func wear(_ item: StoreItem) {
        guard owns(item) else { return }
        switch item.thing {
        case .top(let t, let c): outfit.top = t; outfit.topColor = c
        case .bottom(let b, let c):
            outfit.bottom = b; outfit.bottomColor = c
            if outfit.top == .dress { outfit.top = .none }
        case .shoes(let s, let c): outfit.shoes = s; outfit.shoeColor = c
        case .pet: pet = item.id
        case .food: break
        }
        outfit = outfit.normalized
    }

    /// Take it off (or send the pet home). Shoes go back to the starter sneakers.
    public mutating func takeOff(_ item: StoreItem) {
        guard isWearing(item) else { return }
        switch item.thing {
        case .top: outfit.top = .none
        case .bottom: outfit.bottom = .none
        case .shoes: outfit.shoes = Outfit.starter.shoes; outfit.shoeColor = Outfit.starter.shoeColor
        case .pet: pet = nil
        case .food: break
        }
    }

    /// Sell something you own back to a shop for half its price. Returns the coins paid, or nil.
    public mutating func sell(_ item: StoreItem) -> Int? {
        guard !item.isFood, owns(item) else { return nil }
        takeOff(item)
        items.remove(item.id)
        coins += item.resale
        return item.resale
    }

    /// The free café snack: once a day, while food can still give rolls.
    public mutating func takeFreeSnack() -> Bool {
        guard !freeSnackTaken, foodRollsLeft >= StoreItem.freeSnackRolls else { return false }
        freeSnackTaken = true
        rolls += StoreItem.freeSnackRolls
        foodRollsToday += StoreItem.freeSnackRolls
        return true
    }
}
