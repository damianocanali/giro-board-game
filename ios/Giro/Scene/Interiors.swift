import RealityKit
import UIKit
import simd

/// Rooms you can walk into: shops, cafés and your home. Each room is built far from the city
/// and shown by moving the camera there; the city keeps running outside.
extension CityScene {
    private static let roomOrigin = SIMD3<Float>(400, 0, 0)

    func showInterior(_ v: StoreVisit, skin: Skin, outfit: Outfit, pet: StoreItem?) {
        hideInterior()
        let room = Entity()
        room.position = Self.roomOrigin
        buildRoom(v.kind, into: room)
        if v.kind != .home {
            let seed = v.owner.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
            let colors: [UInt32] = [0xF1C8A0, 0xD9A066, 0x8D5A3B, 0xE8B98A, 0x6B4226]
            let keeper = makeCharacter(color: colors[seed % colors.count], outfit: .sample(seed), scale: 1, eyes: true)
            keeper.position = [1.6, 0, -1.6]
            room.addChild(keeper)
            waver = keeper.findEntity(named: "armR")
        }
        room.addChild(visitor(skin: skin, outfit: outfit, pet: pet, home: v.kind == .home))
        let lamp = PointLight()
        lamp.light.intensity = 9000
        lamp.light.attenuationRadius = 12
        lamp.position = [0, 3.4, 1]
        room.addChild(lamp)
        world.addChild(room)
        interior = room
        interiorClock = 0

        savedCamera = (target, goalDistance, theta, phi, followPawn)
        followPawn = false
        showcase = false
        goalTarget = Self.roomOrigin + [0, -1.1, 1.2]
        target = goalTarget
        goalDistance = 22
        distance = goalDistance
        theta = .pi / 2
        phi = 0.92
    }

    func hideInterior() {
        guard let room = interior else { return }
        room.removeFromParent()
        interior = nil
        waver = nil
        if let s = savedCamera {
            target = s.target
            goalTarget = s.target
            distance = s.distance
            goalDistance = s.distance
            theta = s.theta
            phi = s.phi
            followPawn = s.follow
        }
        savedCamera = nil
    }

    /// Redress the player inside the room after buying or changing clothes.
    func refreshVisitor(skin: Skin, outfit: Outfit, pet: StoreItem?, home: Bool) {
        guard let room = interior else { return }
        room.findEntity(named: "visitor")?.removeFromParent()
        room.addChild(visitor(skin: skin, outfit: outfit, pet: pet, home: home))
    }

    /// The shopkeeper waves hello when you come in, and again every few seconds.
    func animateInterior(_ dt: Float) {
        interiorClock += dt
        guard let arm = waver else { return }
        let t = interiorClock.truncatingRemainder(dividingBy: 7)
        let raise: Float = t < 0.3 ? t / 0.3 : t < 1.9 ? 1 : t < 2.2 ? (2.2 - t) / 0.3 : 0
        arm.orientation = simd_quatf(angle: raise * (2.6 + sin(interiorClock * 10) * 0.3), axis: [0, 0, 1])
    }

    // MARK: Building the room

    /// You, standing in the room and looking at the counter, with your pet beside you.
    private func visitor(skin: Skin, outfit: Outfit, pet: StoreItem?, home: Bool) -> Entity {
        let g = Entity()
        g.name = "visitor"
        let me = makeCharacter(color: skin.pawn, outfit: outfit, scale: 1, eyes: true)
        addHat(skin.hat, color: skin.hatColor, to: me)
        me.position = home ? [0.4, 0, 0.9] : [-0.4, 0, 0.6]
        let face = home ? SIMD3<Float>(0, 0, 3) : SIMD3<Float>(1.6, 0, -1.6) - me.position
        me.orientation = simd_quatf(angle: atan2(face.x, face.z), axis: [0, 1, 0])
        g.addChild(me)
        if let pet, case .pet(let kind, let color) = pet.thing {
            let p = makePet(kind, color: color)
            p.scale *= 1.8
            p.position = me.position + [-0.7, 0, 0.3]
            p.orientation = simd_quatf(angle: 0.6, axis: [0, 1, 0])
            g.addChild(p)
        }
        return g
    }

    private static func roomColors(_ k: StoreKind) -> (wall: UInt32, floor: UInt32) {
        switch k {
        case .clothes: (0xF7D9E3, 0xE9D2B4)
        case .shoes: (0xDCE8F5, 0xD8C3A5)
        case .pets: (0xDDEFD6, 0xD9C7A3)
        case .grocery: (0xFBE7C2, 0xE2D6C2)
        case .cafe: (0xEAD7C3, 0xB8916A)
        case .home: (0xF4E8D6, 0xC9A27E)
        }
    }

    private func buildRoom(_ kind: StoreKind, into room: Entity) {
        let (wall, floor) = Self.roomColors(kind)
        let wood: UInt32 = 0xB8784A, trim: UInt32 = 0xFFF7EC
        // An open-fronted box, like a dolls' house.
        part(box(8, 0.2, 10), floor, [0, -0.1, 2], in: room)
        part(box(8, 4.6, 0.2), wall, [0, 2.3, -3], in: room)
        part(box(0.2, 4.6, 6), wall, [-4, 2.3, 0], in: room)
        part(box(0.2, 4.6, 6), wall, [4, 2.3, 0], in: room)
        part(box(8, 0.22, 0.24), trim, [0, 0.11, -2.9], in: room)
        // A window with a view of the sky.
        part(box(1.9, 1.4, 0.06), trim, [2.3, 2.7, -2.88], in: room)
        part(box(1.7, 1.2, 0.06), Theme.skyHex, [2.3, 2.7, -2.85], in: room)
        part(box(0.06, 1.2, 0.08), trim, [2.3, 2.7, -2.83], in: room)

        switch kind {
        case .home:
            buildHome(into: room)
        default:
            // Counter, with a till, where the shopkeeper stands.
            part(box(2.6, 0.42, 0.6, r: 0.06), wood, [1.6, 0.21, -1.0], in: room)
            part(box(2.8, 0.06, 0.75, r: 0.03), trim, [1.6, 0.45, -1.0], in: room)
            part(box(0.34, 0.24, 0.26, r: 0.05), 0x5A6B7A, [2.55, 0.6, -1.0], in: room)
            // Shelves on the back wall, stocked with what the shop sells.
            let items = kind.items
            for row in 0..<3 {
                let y = 0.7 + Float(row) * 0.8
                part(box(3.4, 0.08, 0.6, r: 0.02), wood, [-1.9, y, -2.6], in: room)
                for k in 0..<5 where !items.isEmpty {
                    let p = product(kind, items[(row * 5 + k) % items.count], k)
                    p.position = [-3.3 + Float(k) * 0.7, y + 0.04, -2.6]
                    room.addChild(p)
                }
            }
            for x: Float in [-3.65, -0.15] { part(box(0.08, 2.5, 0.6), wood, [x, 1.25, -2.6], in: room) }
            if kind == .cafe {
                // A little table and two stools out front.
                part(cylinder(0.08, 0.6), trim, [-2.6, 0.78, 0.6], in: room)
                part(cylinder(0.74, 0.07), wood, [-2.6, 0.37, 0.6], in: room)
                for dx: Float in [-0.75, 0.75] { part(cylinder(0.45, 0.22), 0xE5533D, [-2.6 + dx, 0.225, 0.6], in: room) }
                let cup = product(.cafe, items.first, 1)
                cup.position = [-2.6, 0.82, 0.6]
                room.addChild(cup)
            }
            if kind == .pets {
                // Two of the pets play on the floor.
                for (i, item) in items.filter(\.isPet).prefix(2).enumerated() {
                    let p = product(.pets, item, i)
                    p.position = [-2.4 + Float(i) * 1.1, 0, 0.3]
                    p.orientation = simd_quatf(angle: 0.5 - Float(i), axis: [0, 1, 0])
                    room.addChild(p)
                }
            }
        }
    }

    private func buildHome(into room: Entity) {
        let wood: UInt32 = 0xB8784A
        // Rug, sofa, bed, plant, lamp and a TV on the wall.
        part(cylinder(0.02, 1.7), 0xE5A0A0, [0, 0.01, 0.3], in: room)
        part(box(2.4, 0.45, 0.95, r: 0.12), 0x4A90D9, [-2.2, 0.32, -2.2], in: room)
        part(box(2.4, 0.7, 0.3, r: 0.12), 0x4A90D9, [-2.2, 0.75, -2.6], in: room)
        for x: Float in [-3.35, -1.05] { part(box(0.25, 0.65, 0.95, r: 0.1), 0x3B78BD, [x, 0.4, -2.2], in: room) }
        part(box(1.7, 0.45, 2.3, r: 0.08), wood, [2.6, 0.25, -1.6], in: room)
        part(box(1.6, 0.18, 2.2, r: 0.08), 0xFFFFFF, [2.6, 0.55, -1.6], in: room)
        part(box(1.62, 0.2, 1.4, r: 0.08), 0x5DBB63, [2.6, 0.6, -1.2], in: room)
        part(box(0.9, 0.2, 0.45, r: 0.08), 0xFFF7EC, [2.6, 0.7, -2.4], in: room)
        part(box(1.5, 0.85, 0.08, r: 0.03), 0x2B2B2B, [-2.2, 2.4, -2.88], in: room)
        part(cylinder(0.45, 0.25), 0xD9A066, [3.4, 0.225, 1.6], in: room)
        part(sphere(0.45), 0x3E9D4E, [3.4, 0.8, 1.6], in: room)
        part(cylinder(1.6, 0.04), 0x5A4A3A, [-3.4, 0.8, 1.0], in: room)
        part(cone(0.35, 0.3), 0xFFE9A8, [-3.4, 1.7, 1.0], in: room)
    }

    /// One thing on a shelf, in the item's own colour where it has one.
    private func product(_ kind: StoreKind, _ item: StoreItem?, _ i: Int) -> Entity {
        let g = Entity()
        switch item?.thing {
        case .top(_, let c)?, .bottom(_, let c)?:
            // A small stack of folded clothes.
            part(box(0.46, 0.13, 0.34, r: 0.04), c, [0, 0.065, 0], in: g)
            part(box(0.42, 0.12, 0.3, r: 0.04), c, [0, 0.19, 0], in: g)
        case .shoes(_, let c)?:
            for x: Float in [-0.09, 0.09] {
                part(box(0.15, 0.04, 0.32, r: 0.015), 0xFFFFFF, [x, 0.02, 0], in: g)
                part(box(0.14, 0.11, 0.3, r: 0.045), c, [x, 0.09, -0.02], in: g)
            }
        case .pet(let k, let c)?:
            let p = makePet(k, color: c)
            p.scale *= 1.5
            g.addChild(p)
        default:
            if kind == .cafe {
                if i % 2 == 0 {
                    // Cake with cream and a cherry.
                    part(cylinder(0.2, 0.2), 0xF7B6CF, [0, 0.1, 0], in: g)
                    part(cylinder(0.05, 0.21), 0xFFF7EC, [0, 0.22, 0], in: g)
                    part(sphere(0.05), 0xE5533D, [0, 0.28, 0], in: g)
                } else {
                    // Cup and saucer.
                    part(cylinder(0.02, 0.15), 0xFFFFFF, [0, 0.01, 0], in: g)
                    part(cylinder(0.16, 0.09), 0xFFFFFF, [0, 0.1, 0], in: g)
                    part(cylinder(0.01, 0.08), 0x6B4226, [0, 0.18, 0], in: g)
                }
            } else {
                // Groceries: a crate of fruit or a bright packet.
                let fruit: [UInt32] = [0xE5533D, 0xF28C28, 0x5DBB63, 0xF5C542]
                if i % 2 == 0 {
                    part(box(0.5, 0.14, 0.36, r: 0.03), 0xD9A066, [0, 0.07, 0], in: g)
                    for k in 0..<4 { part(sphere(0.09), fruit[(i + k) % 4], [Float(k % 2) * 0.2 - 0.1, 0.2, Float(k / 2) * 0.16 - 0.08], in: g) }
                } else {
                    part(box(0.26, 0.4, 0.14, r: 0.03), fruit[i % 4], [0, 0.2, 0], in: g)
                    part(box(0.2, 0.12, 0.15, r: 0.02), 0xFFF7EC, [0, 0.22, 0], in: g)
                }
            }
        }
        return g
    }
}
