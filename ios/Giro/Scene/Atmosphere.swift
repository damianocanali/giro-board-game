import RealityKit
import UIKit
import simd

/// Weather and holiday decorations for the city.
extension CityScene {
    /// Sky colour and sun strength for each weather.
    static func sky(_ w: Weather) -> (sky: UInt32, sun: Float) {
        switch w {
        case .sunny: (Theme.skyHex, 2600)
        case .cloudy: (0xE3D6C6, 1800)
        case .rain: (0xB9C2CC, 1300)
        case .snow: (0xE6EBF1, 1900)
        }
    }

    /// Rain streaks, snowflakes or drifting clouds that follow the camera.
    func makeWeather(_ w: Weather, into root: Entity) {
        root.children.removeAll()
        switch w {
        case .rain:
            let m = UnlitMaterial(color: UIColor(hex: 0x7F9BB8))
            for _ in 0..<220 {
                let e = ModelEntity(mesh: box(0.03, 0.7, 0.03), materials: [m])
                e.position = [Float.random(in: -32...32), Float.random(in: 0...26), Float.random(in: -32...32)]
                e.name = "drop"
                root.addChild(e)
            }
        case .snow:
            let m = UnlitMaterial(color: .white)
            for _ in 0..<200 {
                let e = ModelEntity(mesh: sphere(0.09), materials: [m])
                e.position = [Float.random(in: -32...32), Float.random(in: 0...26), Float.random(in: -32...32)]
                e.name = "flake"
                root.addChild(e)
            }
        case .cloudy, .sunny:
            break
        }
        let clouds = w == .sunny ? 3 : 8
        let shade: UInt32 = w == .rain ? 0xC7CDD4 : 0xFFFFFF
        for i in 0..<clouds {
            let c = Entity()
            c.name = "cloud"
            for k in 0..<4 {
                part(sphere(1.6 + Float(k % 2) * 0.6), shade, [Float(k) * 1.5 - 2.2, Float(k % 2) * 0.5, Float((k * 7) % 3) - 1], in: c)
            }
            c.position = [Float(i) * 13 - 40, 22 + Float(i % 3) * 2, Float((i * 17) % 50) - 25]
            root.addChild(c)
        }
    }

    /// Move rain, snow and clouds. Called every frame.
    func animateWeather(_ root: Entity, center: SIMD3<Float>, dt: Float, clock: Float) {
        for e in root.children {
            switch e.name {
            case "drop":
                e.position.y -= 34 * dt
                if e.position.y < 0 { e.position = [center.x + Float.random(in: -32...32), 26, center.z + Float.random(in: -32...32)] }
            case "flake":
                e.position.y -= 2.6 * dt
                e.position.x += sin(clock * 1.3 + e.position.z) * 0.6 * dt
                if e.position.y < 0 { e.position = [center.x + Float.random(in: -32...32), 26, center.z + Float.random(in: -32...32)] }
            case "cloud":
                e.position.x += 0.9 * dt
                if e.position.x > 60 { e.position.x = -60 }
            default:
                break
            }
        }
    }

    /// Holiday props on the city: everywhere on other players' blocks, and on yours only if you own the pack.
    func makeDecorations(_ h: Holiday?, ownPack: Bool, map: CityMap, into root: Entity) {
        root.children.removeAll()
        guard let h else { return }
        var n = 0
        for y in 0..<CityMap.size {
            for x in 0..<CityMap.size {
                let c = Cell(x, y)
                let t = map.tiles[y][x]
                let mine = map.ownership(of: c) == .mine
                guard t != .road, !t.isMonument, (x * 31 + y * 17) % (mine ? 2 : 5) == 0, !mine || ownPack else { continue }
                let g = Entity()
                g.position = Self.position(c, y: Self.blockTop) + [0.62, 0, 0.62]
                switch h.id {
                case "halloween":
                    let p = part(sphere(0.24), 0xF28C28, [0, 0.2, 0], in: g)
                    p.scale = [1.15, 0.85, 1.15]
                    part(cylinder(0.12, 0.04), 0x3E7D3A, [0, 0.42, 0], in: g)
                    let eyes = UnlitMaterial(color: UIColor(hex: 0xFFE27A))
                    for dx: Float in [-0.08, 0.08] {
                        let e = ModelEntity(mesh: box(0.06, 0.06, 0.02), materials: [eyes])
                        e.position = [dx, 0.24, 0.27]
                        g.addChild(e)
                    }
                case "winter":
                    part(box(0.36, 0.3, 0.36, r: 0.04), [0xD9483B, 0x3E9D4E, 0x4A90D9][n % 3], [0, 0.15, 0], in: g)
                    part(box(0.38, 0.06, 0.1), 0xF5B700, [0, 0.3, 0], in: g)
                    part(box(0.1, 0.06, 0.38), 0xF5B700, [0, 0.3, 0], in: g)
                default:
                    part(cylinder(0.5, 0.05), 0x8A5A3B, [0, 0.25, 0], in: g)
                    part(sphere(0.32), 0xF7B6CF, [0, 0.6, 0], in: g)
                    part(sphere(0.22), 0xFFD1E0, [0.18, 0.7, 0.1], in: g)
                }
                root.addChild(g)
                n += 1
            }
        }
    }
}
