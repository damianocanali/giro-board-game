import RealityKit
import simd

/// Toy-style monuments made of simple shapes. Each one stands on a single square, faces +z
/// (the street side, after the cell is turned) and may rise well above the other buildings.
extension CityScene {
    func buildMonument(_ t: Tile, into b: Entity) {
        let top = Self.blockTop
        switch t {
        case .liberty:
            let stone: UInt32 = 0xD8C9A8, copper: UInt32 = 0x7CC7A9
            part(box(1.7, 0.3, 1.7, r: 0.04), stone, [0, top + 0.15, 0], in: b)
            part(box(1.1, 1.1, 1.1, r: 0.04), stone, [0, top + 0.85, 0], in: b)
            part(box(1.25, 0.12, 1.25, r: 0.03), 0xC4B38F, [0, top + 1.46, 0], in: b)
            part(cone(1.7, 0.42), copper, [0, top + 2.37, 0], in: b)
            part(sphere(0.2), copper, [0, top + 3.32, 0], in: b)
            for k in 0..<7 {
                let a = Float(k) / 6 * 2.4 - 1.2 // fan across the front
                let spike = part(cone(0.24, 0.04), copper, [sin(a) * 0.2, top + 3.48, cos(a) * 0.2], in: b)
                spike.orientation = simd_quatf(angle: 0.6, axis: simd_normalize([cos(a), 0, -sin(a)]))
            }
            let arm = part(cylinder(0.9, 0.07), copper, [0.3, top + 3.35, 0], in: b)
            arm.orientation = simd_quatf(angle: -0.25, axis: [0, 0, 1])
            part(cylinder(0.1, 0.12), 0xC9A227, [0.42, top + 3.82, 0], in: b)
            let flame = ModelEntity(mesh: cone(0.26, 0.1), materials: [unlit(0xFFB627)])
            flame.position = [0.42, top + 4.0, 0]
            b.addChild(flame)
            part(box(0.1, 0.42, 0.3, r: 0.02), copper, [-0.33, top + 2.5, 0.12], in: b)

        case .empireState:
            let stone: UInt32 = 0xDDD5C4
            var y = top
            for (w, h) in [(1.7, 0.6), (1.35, 2.8), (1.05, 0.8), (0.78, 0.6), (0.5, 0.45)] as [(Float, Float)] {
                part(box(w, h, w, r: 0.04), stone, [0, y + h / 2, 0], in: b)
                if h > 1 {
                    var band = y + 0.4
                    while band < y + h - 0.2 {
                        part(box(w + 0.04, 0.05, w + 0.04), 0x8FA3B8, [0, band, 0], in: b)
                        band += 0.4
                    }
                }
                y += h
            }
            part(cylinder(1.3, 0.05), 0xBFC6CC, [0, y + 0.65, 0], in: b)
            part(sphere(0.08), 0xE5533D, [0, y + 1.32, 0], in: b)

        case .colosseum:
            let tan: UInt32 = 0xD9B98A, dark: UInt32 = 0xB8935F
            part(cylinder(0.06, 0.72), 0xE8D3A8, [0, top + 0.03, 0], in: b)
            let n = 22
            for i in 0..<n {
                let a = Float(i) / Float(n) * 2 * .pi
                // One side is ruined and lower, like the real one.
                let ruined = a > 3.6 && a < 5.0
                let h: Float = ruined ? 0.7 : 1.35
                let p = SIMD3<Float>(cos(a) * 0.82, 0, sin(a) * 0.82)
                let pillar = part(box(0.11, h, 0.16), tan, p + [0, top + h / 2, 0], in: b)
                pillar.orientation = simd_quatf(angle: -a, axis: [0, 1, 0])
                for (k, ring) in [Float(0.05), 0.5, 0.95, 1.35].enumerated() where ring <= h {
                    let seg = part(box(0.26, k == 0 ? 0.1 : 0.07, 0.2), k == 0 ? dark : tan, p + [0, top + ring, 0], in: b)
                    seg.orientation = simd_quatf(angle: -a + .pi / 2, axis: [0, 1, 0])
                }
            }

        case .stPeters:
            let marble: UInt32 = 0xEDE3CF
            part(box(1.7, 0.8, 1.3, r: 0.04), marble, [0, top + 0.4, -0.15], in: b)
            for i in 0..<6 {
                part(cylinder(0.7, 0.06), 0xFFFFFF, [-0.6 + Float(i) * 0.24, top + 0.35, 0.58], in: b)
            }
            part(box(1.6, 0.12, 0.3), marble, [0, top + 0.76, 0.58], in: b)
            part(cylinder(0.45, 0.46), marble, [0, top + 1.02, -0.15], in: b)
            let dome = part(sphere(0.48), 0x9DB8C9, [0, top + 1.25, -0.15], in: b)
            dome.scale = [1, 1.15, 1]
            part(cylinder(0.3, 0.1), marble, [0, top + 1.9, -0.15], in: b)
            part(cone(0.22, 0.12), 0x9DB8C9, [0, top + 2.15, -0.15], in: b)

        case .eiffel:
            let iron: UInt32 = 0x8A5A3B
            for (sx, sz) in [(Float(-1), Float(-1)), (1, -1), (1, 1), (-1, 1)] {
                leg(from: [sx * 0.72, top, sz * 0.72], to: [sx * 0.32, top + 1.7, sz * 0.32], width: 0.16, color: iron, in: b)
                leg(from: [sx * 0.32, top + 1.7, sz * 0.32], to: [sx * 0.13, top + 3.2, sz * 0.13], width: 0.1, color: iron, in: b)
            }
            part(box(0.95, 0.1, 0.95, r: 0.02), iron, [0, top + 1.7, 0], in: b)
            part(box(0.42, 0.08, 0.42, r: 0.02), iron, [0, top + 3.2, 0], in: b)
            part(box(0.18, 1.3, 0.18, r: 0.02), iron, [0, top + 3.85, 0], in: b)
            part(cylinder(0.5, 0.03), iron, [0, top + 4.75, 0], in: b)
            // The arches under the first floor.
            for r in [Float(0), .pi / 2] {
                let arch = part(box(1.1, 0.12, 0.06), iron, [0, top + 0.95, 0], in: b)
                arch.orientation = simd_quatf(angle: r, axis: [0, 1, 0])
            }

        case .arc:
            let stone: UInt32 = 0xE8DCC0
            part(box(0.5, 1.6, 0.8, r: 0.03), stone, [-0.5, top + 0.8, 0], in: b)
            part(box(0.5, 1.6, 0.8, r: 0.03), stone, [0.5, top + 0.8, 0], in: b)
            part(box(1.5, 0.7, 0.8, r: 0.03), stone, [0, top + 1.95, 0], in: b)
            part(box(1.62, 0.1, 0.9, r: 0.02), 0xD4C4A0, [0, top + 2.35, 0], in: b)
            part(box(1.5, 0.08, 0.82), 0xD4C4A0, [0, top + 1.62, 0], in: b)

        case .bigBen:
            let stone: UInt32 = 0xD9B77A
            part(box(1.2, 0.45, 1.0, r: 0.03), stone, [0, top + 0.22, 0], in: b)
            part(box(0.68, 2.9, 0.68, r: 0.03), stone, [0, top + 1.45, 0], in: b)
            part(box(0.8, 0.75, 0.8, r: 0.03), stone, [0, top + 3.2, 0], in: b)
            for k in 0..<4 {
                let a = Float(k) * .pi / 2
                let face = part(cylinder(0.03, 0.27), 0xFFF7E0, [sin(a) * 0.41, top + 3.2, cos(a) * 0.41], in: b)
                face.orientation = simd_quatf(angle: .pi / 2, axis: [cos(a), 0, -sin(a)])
                let hand = part(box(0.03, 0.2, 0.02), 0x2B1A10, [sin(a) * 0.43, top + 3.26, cos(a) * 0.43], in: b)
                hand.orientation = simd_quatf(angle: a, axis: [0, 1, 0])
            }
            part(box(0.6, 0.4, 0.6, r: 0.03), stone, [0, top + 3.77, 0], in: b)
            part(pyramid(0.7, 0.9), 0x3F5A4A, [0, top + 3.97, 0], in: b)
            part(cylinder(0.35, 0.025), 0xC9A227, [0, top + 5.0, 0], in: b)

        case .londonEye:
            let white: UInt32 = 0xF2F2F2
            let center = SIMD3<Float>(0, top + 1.75, 0)
            let r: Float = 1.35
            for i in 0..<28 {
                let a = Float(i) / 28 * 2 * .pi
                let seg = part(box(0.32, 0.05, 0.06), white, center + [cos(a) * r, sin(a) * r, 0], in: b)
                seg.orientation = simd_quatf(angle: a + .pi / 2, axis: [0, 0, 1])
            }
            for i in 0..<8 {
                let a = Float(i) / 8 * .pi
                let spoke = part(box(2 * r, 0.02, 0.02), 0xCFCFCF, center, in: b)
                spoke.orientation = simd_quatf(angle: a, axis: [0, 0, 1])
            }
            for i in 0..<12 {
                let a = Float(i) / 12 * 2 * .pi
                part(sphere(0.1), 0x9EC3E6, center + [cos(a) * (r + 0.08), sin(a) * (r + 0.08), 0.06], in: b)
            }
            part(sphere(0.1), white, center, in: b)
            leg(from: [-0.6, top, -0.35], to: center + [0, 0, -0.06], width: 0.08, color: white, in: b)
            leg(from: [0.6, top, -0.35], to: center + [0, 0, -0.06], width: 0.08, color: white, in: b)

        case .tokyoTower:
            var y = top
            let widths: [Float] = [1.3, 1.05, 0.85, 0.68, 0.54, 0.42, 0.32, 0.24, 0.17, 0.12]
            for (i, w) in widths.enumerated() {
                let h: Float = 0.46
                part(box(w, h, w, r: 0.02), i % 2 == 0 ? 0xE5533D : 0xFFFFFF, [0, y + h / 2, 0], in: b)
                if i == 2 || i == 5 { part(box(w + 0.25, 0.14, w + 0.25, r: 0.03), 0xFFFFFF, [0, y + h, 0], in: b) }
                y += h
            }
            part(cylinder(0.6, 0.03), 0xE5533D, [0, y + 0.3, 0], in: b)

        case .pagoda:
            var y = top
            var w: Float = 1.0
            for _ in 0..<5 {
                part(box(w, 0.36, w, r: 0.03), 0xB5522E, [0, y + 0.18, 0], in: b)
                part(box(w + 0.5, 0.07, w + 0.5, r: 0.03), 0x3C3C46, [0, y + 0.4, 0], in: b)
                part(pyramid(w + 0.4, 0.16), 0x3C3C46, [0, y + 0.43, 0], in: b)
                y += 0.55
                w -= 0.13
            }
            part(cylinder(0.7, 0.03), 0xC9A227, [0, y + 0.3, 0], in: b)
            for k in 0..<4 { part(sphere(0.05), 0xC9A227, [0, y + 0.1 + Float(k) * 0.15, 0], in: b) }

        case .pyramids:
            part(box(1.9, 0.04, 1.9, r: 0.03), 0xEBD49A, [0, top + 0.02, 0], in: b)
            part(pyramid(1.5, 1.35), 0xE2C27D, [-0.2, top + 0.04, -0.2], in: b)
            part(pyramid(0.62, 0.55), 0xD9B068, [0.62, top + 0.04, 0.55], in: b)
            part(pyramid(0.4, 0.35), 0xD9B068, [0.62, top + 0.04, -0.6], in: b)

        case .sphinx:
            let sand: UInt32 = 0xD9B068
            part(box(1.9, 0.04, 1.9, r: 0.03), 0xEBD49A, [0, top + 0.02, 0], in: b)
            part(box(0.62, 0.5, 1.4, r: 0.12), sand, [0, top + 0.27, -0.2], in: b)
            part(box(0.2, 0.16, 0.55, r: 0.05), sand, [-0.2, top + 0.1, 0.65], in: b)
            part(box(0.2, 0.16, 0.55, r: 0.05), sand, [0.2, top + 0.1, 0.65], in: b)
            part(box(0.42, 0.48, 0.42, r: 0.08), sand, [0, top + 0.72, 0.36], in: b)
            part(box(0.58, 0.36, 0.22, r: 0.04), 0x3F6FB5, [0, top + 0.78, 0.2], in: b)
            part(box(0.08, 0.08, 0.06), 0x2B1A10, [-0.09, top + 0.8, 0.58], in: b)
            part(box(0.08, 0.08, 0.06), 0x2B1A10, [0.09, top + 0.8, 0.58], in: b)

        default:
            break
        }
    }

    /// A straight beam between two points (tower legs, frames).
    func leg(from a: SIMD3<Float>, to c: SIMD3<Float>, width: Float, color: UInt32, in parent: Entity) {
        let d = c - a
        let len = simd_length(d)
        let e = part(box(width, len, width, r: width * 0.2), color, (a + c) / 2, in: parent)
        e.orientation = simd_quatf(from: [0, 1, 0], to: d / len)
    }
}
