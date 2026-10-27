import RealityKit
import UIKit
import Combine
import simd

/// Renders the city board with RealityKit (non-AR) and runs the animations the game asks for.
@MainActor
final class CityScene {
    let arView: ARView

    // Scene graph
    private let world: AnchorEntity
    private let cityRoot: Entity
    private let fxRoot: Entity
    private let coinRoot: Entity
    private let arrowRoot: Entity
    private let trafficRoot: Entity
    private let popRoot: Entity
    private let cameraAnchor: AnchorEntity
    private let camera: PerspectiveCamera
    private(set) var pawn: Entity
    private var die: Entity
    private var cellEntities: [Cell: Entity] = [:]
    private var coinEntities: [Cell: Entity] = [:]
    private var ghostEntities: [Int: Entity] = [:]
    private var ghostOffsets: [Int: SIMD3<Float>] = [:]
    private var updateSubscription: (any Cancellable)?
    private var map: CityMap
    private var cars: [Car] = []
    private var clock: Float = 0

    // Camera rig (orbit around a target that can follow the pawn)
    var theta: Float = -0.8
    var phi: Float = 0.92
    private var distance: Float = 26
    var goalDistance: Float = 26
    private var target = SIMD3<Float>(0, 0, 0)
    private var goalTarget = SIMD3<Float>(0, 0, 0)
    var followPawn = true

    var onTapFork: ((Int) -> Void)?
    var onTapSale: ((Int) -> Void)?

    static let cell: Float = 2
    static let streetTop: Float = 0.22
    static let blockTop: Float = 0.32

    static func position(_ c: Cell, y: Float = 0) -> SIMD3<Float> {
        [Float(c.x) * cell - 30 + 1, y, Float(c.y) * cell - 30 + 1]
    }

    private struct Car {
        var entity: Entity
        var cell: Cell
        var dir: Dir
        var t: Float
        var speed: Float
    }

    // MARK: Setup

    init(map: CityMap) {
        self.map = map
        world = AnchorEntity(world: .zero)
        cityRoot = Entity()
        fxRoot = Entity()
        coinRoot = Entity()
        arrowRoot = Entity()
        trafficRoot = Entity()
        popRoot = Entity()
        cameraAnchor = AnchorEntity(world: .zero)
        camera = PerspectiveCamera()
        pawn = Entity()
        die = Entity()
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(UIColor(hex: Theme.skyHex))
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableCameraGrain)

        arView.scene.addAnchor(world)
        [cityRoot, fxRoot, coinRoot, arrowRoot, trafficRoot, popRoot].forEach { world.addChild($0) }

        camera.camera.fieldOfViewInDegrees = 42
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)

        let sun = DirectionalLight()
        sun.light.intensity = 2600
        sun.light.color = UIColor(hex: 0xFFF1DE)
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 70, depthBias: 3)
        sun.look(at: .zero, from: [22, 40, 14], relativeTo: nil)
        world.addChild(sun)
        let fill = DirectionalLight()
        fill.light.intensity = 700
        fill.light.color = UIColor(hex: 0xFFE0C2)
        fill.look(at: .zero, from: [-20, 18, -24], relativeTo: nil)
        world.addChild(fill)

        let ground = ModelEntity(mesh: .generatePlane(width: 96, depth: 96), materials: [mat(Theme.groundHex)])
        ground.position.y = -0.02
        world.addChild(ground)

        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            let dt = Float(event.deltaTime)
            MainActor.assumeIsolated { self?.update(dt: dt) }
        }
    }

    /// Builds everything for the current game state.
    func setup(map: CityMap, pawnAt cell: Cell, heading: Dir, golden: Bool, pickups: Set<Cell>, ghosts: [Ghost]) {
        self.map = map
        buildCity()
        pawn = makeCharacter(color: golden ? 0xE0A100 : Theme.youHex, scale: 1.25, eyes: true)
        let tag = label("YOU", size: 0.32, fg: 0x4A2E1B, bg: Theme.youHex)
        tag.position.y = 2.15
        pawn.addChild(tag)
        pawn.position = Self.position(cell, y: Self.streetTop)
        pawn.orientation = yaw(heading)
        world.addChild(pawn)
        die = makeDie()
        die.isEnabled = false
        world.addChild(die)
        for c in pickups { addCoin(at: c) }
        let offsets: [SIMD3<Float>] = [[0.4, 0, 0.4], [-0.4, 0, 0.4], [0.4, 0, -0.4], [-0.4, 0, -0.4], [0, 0, 0.5], [0.5, 0, 0]]
        for g in ghosts {
            let e = makeCharacter(color: g.color, scale: 0.85, eyes: true)
            let tag = label("\(g.name) · \(g.city)", size: 0.24, fg: 0x4A2E1B, bg: 0xFFF7EC)
            tag.position.y = 1.75
            e.addChild(tag)
            let off = offsets[g.id % offsets.count]
            ghostOffsets[g.id] = off
            e.position = Self.position(g.cell, y: Self.streetTop) + off
            world.addChild(e)
            ghostEntities[g.id] = e
        }
        spawnCars(16)
        target = pawn.position
        goalTarget = target
    }

    func rebuildAll(map: CityMap, pawnAt cell: Cell) {
        self.map = map
        buildCity()
        pawn.position = Self.position(cell, y: Self.streetTop)
    }

    /// After buying land: rebuild that block, every street tile (their colours depend on ownership) and the plot markers.
    func rebuildBlock(_ b: Int, in map: CityMap) {
        self.map = map
        let o = CityMap.blockOrigin(b)
        for y in o.y..<(o.y + CityMap.blockSize) { for x in o.x..<(o.x + CityMap.blockSize) { buildCell(Cell(x, y)) } }
        for c in map.roadCells { buildCell(c) }
        buildFX()
    }

    // MARK: Materials and meshes

    private var materialCache: [UInt32: SimpleMaterial] = [:]
    private var unlitCache: [UInt32: UnlitMaterial] = [:]
    private var meshCache: [String: MeshResource] = [:]

    private func mat(_ hex: UInt32) -> SimpleMaterial {
        if let m = materialCache[hex] { return m }
        let m = SimpleMaterial(color: UIColor(hex: hex), roughness: 0.85, isMetallic: false)
        materialCache[hex] = m
        return m
    }

    private func unlit(_ hex: UInt32) -> UnlitMaterial {
        if let m = unlitCache[hex] { return m }
        let m = UnlitMaterial(color: UIColor(hex: hex))
        unlitCache[hex] = m
        return m
    }

    private func box(_ w: Float, _ h: Float, _ d: Float, r: Float = 0) -> MeshResource {
        let k = "b\(w)|\(h)|\(d)|\(r)"
        if let m = meshCache[k] { return m }
        let m = MeshResource.generateBox(width: w, height: h, depth: d, cornerRadius: r, splitFaces: false)
        meshCache[k] = m
        return m
    }

    private func sphere(_ r: Float) -> MeshResource {
        let k = "s\(r)"
        if let m = meshCache[k] { return m }
        let m = MeshResource.generateSphere(radius: r)
        meshCache[k] = m
        return m
    }

    private func cylinder(_ h: Float, _ r: Float) -> MeshResource {
        let k = "c\(h)|\(r)"
        if let m = meshCache[k] { return m }
        let m = MeshResource.generateCylinder(height: h, radius: r)
        meshCache[k] = m
        return m
    }

    private func cone(_ h: Float, _ r: Float) -> MeshResource {
        let k = "n\(h)|\(r)"
        if let m = meshCache[k] { return m }
        let m = MeshResource.generateCone(height: h, radius: r)
        meshCache[k] = m
        return m
    }

    /// Square pyramid (house roofs), centred on its base.
    private func pyramid(_ base: Float, _ height: Float) -> MeshResource {
        let k = "p\(base)|\(height)"
        if let m = meshCache[k] { return m }
        let h = base / 2
        let corners: [SIMD3<Float>] = [[-h, 0, -h], [h, 0, -h], [h, 0, h], [-h, 0, h]]
        let apex = SIMD3<Float>(0, height, 0)
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []
        for i in 0..<4 {
            let a = corners[(i + 1) % 4], b = corners[i]
            let n = simd_normalize(simd_cross(b - a, apex - a))
            let base = UInt32(positions.count)
            positions += [a, b, apex]
            normals += [n, n, n]
            indices += [base, base + 1, base + 2]
        }
        var d = MeshDescriptor(name: "pyramid")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.primitives = .triangles(indices)
        let m = (try? MeshResource.generate(from: [d])) ?? box(base, height, base)
        meshCache[k] = m
        return m
    }

    @discardableResult
    private func part(_ mesh: MeshResource, _ hex: UInt32, _ p: SIMD3<Float>, in parent: Entity) -> ModelEntity {
        let e = ModelEntity(mesh: mesh, materials: [mat(hex)])
        e.position = p
        parent.addChild(e)
        return e
    }

    private func yaw(_ d: Dir) -> simd_quatf { simd_quatf(angle: atan2(Float(d.dx), Float(d.dy)), axis: [0, 1, 0]) }

    // MARK: City

    private func buildCity() {
        cityRoot.children.removeAll()
        cellEntities.removeAll()
        for y in 0..<CityMap.size { for x in 0..<CityMap.size { buildCell(Cell(x, y)) } }
        buildFX()
    }

    private func buildCell(_ c: Cell) {
        cellEntities[c]?.removeFromParent()
        let g = Entity()
        g.position = Self.position(c)
        let t = map.tiles[c.y][c.x]
        if t == .road {
            let hex: UInt32
            if map.isIntersection(c) { hex = Theme.crossingHex }
            else if let k = map.squareKind(map.frontage(of: c)) { hex = k.tileColor }
            else { hex = Theme.streetHex }
            part(box(1.84, Self.streetTop, 1.84, r: 0.08), hex, [0, Self.streetTop / 2, 0], in: g)
        } else {
            buildBlockCell(c, tile: t, into: g)
        }
        cityRoot.addChild(g)
        cellEntities[c] = g
    }

    private func buildBlockCell(_ c: Cell, tile t: Tile, into g: Entity) {
        let sale = map.ownership(of: c) == .forSale
        let top = Self.blockTop
        part(box(2.0, top, 2.0), sale ? 0xDCEAB5 : Theme.blockTopHex, [0, top / 2, 0], in: g)
        let b = Entity()
        g.addChild(b)
        let variant = (c.x * 7 + c.y * 13) % 3
        switch t {
        case .house:
            let walls: [UInt32] = [0xF4E2C8, 0xF2C9A0, 0xF7E7A8]
            part(box(1.1, 0.8, 1.0, r: 0.06), walls[variant], [0, top + 0.4, 0], in: b)
            part(pyramid(1.24, 0.6), 0xD9653B, [0, top + 0.8, 0], in: b)
            part(box(0.24, 0.38, 0.05, r: 0.02), 0x7A4A2A, [0, top + 0.19, 0.51], in: b)
        case .apartments:
            let h: Float = 2.2 + Float(variant) * 0.5
            part(box(1.35, h, 1.35, r: 0.06), 0xD9774A, [0, top + h / 2, 0], in: b)
            var y: Float = top + 0.6
            while y < top + h - 0.2 {
                part(box(1.43, 0.07, 1.43, r: 0.02), 0xB5522E, [0, y, 0], in: b)
                y += 0.6
            }
            part(box(1.45, 0.12, 1.45, r: 0.04), 0xF4E2C8, [0, top + h + 0.06, 0], in: b)
        case .office:
            let h: Float = 3.2 + Float(variant) * 0.7
            part(box(1.45, h, 1.45, r: 0.08), 0x9EC3E6, [0, top + h / 2, 0], in: b)
            var y: Float = top + 0.5
            while y < top + h - 0.2 {
                part(box(1.5, 0.06, 1.5, r: 0.02), 0xFFFFFF, [0, y, 0], in: b)
                y += 0.5
            }
        case .shop:
            part(box(1.5, 0.85, 1.25, r: 0.06), 0xF7EBD4, [0, top + 0.425, 0], in: b)
            for i in 0..<4 {
                let s = part(box(0.38, 0.06, 0.5), i % 2 == 0 ? 0xE5533D : 0xFFFFFF, [-0.57 + Float(i) * 0.38, top + 0.72, 0.78], in: b)
                s.orientation = simd_quatf(angle: 0.35, axis: [1, 0, 0])
            }
            part(box(0.9, 0.2, 0.06, r: 0.02), 0xE5533D, [0, top + 0.95, 0.64], in: b)
        case .cafe:
            part(box(1.0, 0.7, 0.9, r: 0.06), 0xB8784A, [-0.35, top + 0.35, -0.3], in: b)
            for (i, p) in [SIMD2<Float>(0.45, 0.35), SIMD2<Float>(-0.2, 0.55)].enumerated() {
                part(cylinder(0.6, 0.03), 0x5B4636, [p.x, top + 0.3, p.y], in: b)
                part(cone(0.24, 0.42), i == 0 ? 0xF7EBD4 : 0xE5533D, [p.x, top + 0.7, p.y], in: b)
                part(cylinder(0.04, 0.2), 0xFFFFFF, [p.x, top + 0.32, p.y], in: b)
            }
        case .school:
            part(box(1.6, 1.0, 1.3, r: 0.06), 0xF5D76E, [0, top + 0.5, 0], in: b)
            part(box(1.68, 0.1, 1.38, r: 0.03), 0xB5522E, [0, top + 1.05, 0], in: b)
            part(cylinder(1.4, 0.03), 0xDDDDDD, [0.7, top + 0.7, 0.75], in: b)
            part(box(0.35, 0.22, 0.02), 0xB49CF0, [0.88, top + 1.25, 0.75], in: b)
        case .park:
            part(box(1.88, 0.06, 1.88, r: 0.05), 0x7CC36B, [0, top + 0.03, 0], in: b)
            addTree([-0.5, top, -0.45], 1.15, into: b)
            addTree([0.5, top, -0.3], 0.95, into: b)
            addTree([-0.2, top, 0.55], 1.05, into: b)
            part(box(0.5, 0.12, 0.16, r: 0.03), 0x8A5A3B, [0.45, top + 0.12, 0.45], in: b)
        case .plaza:
            part(box(1.88, 0.05, 1.88, r: 0.05), 0xEDE6DA, [0, top + 0.025, 0], in: b)
            part(cylinder(0.18, 0.62), 0xD8CDBB, [0, top + 0.09, 0], in: b)
            part(cylinder(0.04, 0.52), 0x6EC6EA, [0, top + 0.19, 0], in: b)
            part(cylinder(0.5, 0.08), 0xD8CDBB, [0, top + 0.3, 0], in: b)
        case .busStop:
            part(box(1.0, 0.06, 0.45, r: 0.02), 0x14B8C8, [0, top + 0.83, 0], in: b)
            part(box(1.0, 0.75, 0.05), 0xBFE9F0, [0, top + 0.375, -0.2], in: b)
            part(box(0.7, 0.1, 0.2, r: 0.03), 0x555555, [0, top + 0.3, 0], in: b)
            part(cylinder(1.1, 0.03), 0x777777, [0.6, top + 0.55, 0.25], in: b)
            part(sphere(0.15), 0x14B8C8, [0.6, top + 1.12, 0.25], in: b)
        case .empty:
            if !sale && (c.x * 13 + c.y * 7) % 4 == 0 { addTree([0.3, top, 0.2], 0.85, into: b) }
            if sale && (c.x + c.y) % 3 == 0 { addTree([-0.3, top, 0.3], 1.0, into: b) }
        case .road:
            break
        }
        // Face the building toward its street.
        let face: Float
        if map.isRoad(c.moved(.south)) { face = 0 }
        else if map.isRoad(c.moved(.east)) { face = .pi / 2 }
        else if map.isRoad(c.moved(.north)) { face = .pi }
        else if map.isRoad(c.moved(.west)) { face = -.pi / 2 }
        else { face = 0 }
        b.orientation = simd_quatf(angle: face, axis: [0, 1, 0])
    }

    private func addTree(_ p: SIMD3<Float>, _ s: Float, into parent: Entity) {
        part(cylinder(0.4 * s, 0.07 * s), 0x8A5A3B, p + [0, 0.2 * s, 0], in: parent)
        part(sphere(0.34 * s), 0x5DAA4E, p + [0, 0.62 * s, 0], in: parent)
    }

    /// Plot outlines, for-sale signs, owner labels and the bus line.
    private func buildFX() {
        fxRoot.children.removeAll()
        let S = Float(CityMap.blockSize) * Self.cell
        for b in map.ownership.indices {
            let o = CityMap.blockOrigin(b)
            let corner = Self.position(o) - [Self.cell / 2, 0, Self.cell / 2]
            let center = corner + [S / 2, 0, S / 2]
            switch map.ownership[b] {
            case .mine:
                let y = Self.blockTop + 0.03
                for (p, w, d) in [(SIMD3<Float>(center.x, y, corner.z), S, Float(0.18)), (SIMD3<Float>(center.x, y, corner.z + S), S, 0.18),
                                  (SIMD3<Float>(corner.x, y, center.z), 0.18, S), (SIMD3<Float>(corner.x + S, y, center.z), 0.18, S)] {
                    let e = ModelEntity(mesh: box(w, 0.06, d), materials: [unlit(Theme.youHex)])
                    e.position = p
                    fxRoot.addChild(e)
                }
            case .forSale:
                let sign = label("FOR SALE · \(map.plotPrices[b] ?? 0) coins", size: 0.42, fg: 0x4A2E1B, bg: 0xFFFFFF)
                sign.position = center + [0, 3.4, 0]
                sign.name = "sale-\(b)"
                sign.generateCollisionShapes(recursive: true)
                fxRoot.addChild(sign)
                part(cylinder(2.6, 0.06), 0xFFFFFF, center + [0, 1.3, 0], in: fxRoot)
            case .other:
                if b % 3 == 0 {
                    let tag = label("\(map.owners[b].name) · \(map.owners[b].city)", size: 0.36, fg: 0x4A2E1B, bg: 0xFFF7EC)
                    tag.position = center + [0, 5.0, 0]
                    fxRoot.addChild(tag)
                }
            }
        }
        let route = map.busRoute
        for i in route.indices {
            let a = Self.position(route[i]), bb = Self.position(route[(i + 1) % route.count])
            let horizontal = abs(a.z - bb.z) < 0.01
            let e = ModelEntity(mesh: box(horizontal ? Self.cell : 0.2, 0.02, horizontal ? 0.2 : Self.cell), materials: [unlit(0x14B8C8)])
            e.position = (a + bb) / 2 + [0, Self.streetTop + 0.01, 0]
            fxRoot.addChild(e)
        }
    }

    // MARK: Characters, die, labels

    private func makeCharacter(color: UInt32, scale: Float, eyes: Bool) -> Entity {
        let g = Entity()
        let body = part(sphere(0.36), color, [0, 0.5, 0], in: g)
        body.scale = [1, 1.25, 1]
        part(sphere(0.3), color, [0, 1.08, 0], in: g)
        part(sphere(0.11), color, [-0.38, 0.55, 0], in: g)
        part(sphere(0.11), color, [0.38, 0.55, 0], in: g)
        part(sphere(0.12), color, [-0.16, 0.1, 0.05], in: g)
        part(sphere(0.12), color, [0.16, 0.1, 0.05], in: g)
        if eyes {
            part(sphere(0.045), 0x2B1A10, [-0.1, 1.12, 0.27], in: g)
            part(sphere(0.045), 0x2B1A10, [0.1, 1.12, 0.27], in: g)
        }
        g.scale = [scale, scale, scale]
        return g
    }

    func setGoldenPawn(_ on: Bool) {
        let hex: UInt32 = on ? 0xE0A100 : Theme.youHex
        for case let m as ModelEntity in pawn.children where (m.model?.mesh.bounds.extents.x ?? 0) > 0.15 {
            m.model?.materials = [mat(hex)]
        }
    }

    private func makeDie() -> Entity {
        let g = Entity()
        part(box(1.3, 1.3, 1.3, r: 0.22), 0xFFFDF8, .zero, in: g)
        // Faces: +y 1, -y 6, +z 2, -z 5, +x 3, -x 4 (opposites add to 7).
        let pips: [Int: [SIMD2<Float>]] = [
            1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]],
            4: [[-1, -1], [1, -1], [-1, 1], [1, 1]], 5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]],
            6: [[-1, -1], [-1, 0], [-1, 1], [1, -1], [1, 0], [1, 1]],
        ]
        let faces: [(Int, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            (1, [0, 1, 0], [1, 0, 0], [0, 0, 1]), (6, [0, -1, 0], [1, 0, 0], [0, 0, 1]),
            (2, [0, 0, 1], [1, 0, 0], [0, 1, 0]), (5, [0, 0, -1], [1, 0, 0], [0, 1, 0]),
            (3, [1, 0, 0], [0, 0, 1], [0, 1, 0]), (4, [-1, 0, 0], [0, 0, 1], [0, 1, 0]),
        ]
        for (v, n, u, w) in faces {
            for p in pips[v] ?? [] {
                let e = part(sphere(0.11), v == 1 ? 0xE5533D : 0x2B1A10, n * 0.6 + (u * p.x + w * p.y) * 0.34, in: g)
                e.scale = SIMD3<Float>(repeating: 1) - simd_abs(n) * 0.55
            }
        }
        return g
    }

    private static func dieRotation(showing v: Int) -> simd_quatf {
        switch v {
        case 6: simd_quatf(angle: .pi, axis: [1, 0, 0])
        case 2: simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        case 5: simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        case 3: simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        case 4: simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
        default: simd_quatf(angle: 0, axis: [0, 1, 0])
        }
    }

    private func label(_ text: String, size: Float, fg: UInt32, bg: UInt32?) -> Entity {
        let holder = Entity()
        holder.components.set(BillboardComponent())
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.01, font: .systemFont(ofSize: CGFloat(size), weight: .heavy),
                                             containerFrame: .zero, alignment: .center, lineBreakMode: .byClipping)
        let t = ModelEntity(mesh: mesh, materials: [unlit(fg)])
        let bounds = mesh.bounds
        t.position = [-bounds.center.x, -bounds.center.y, 0.03]
        t.components.set(DynamicLightShadowComponent(castsShadow: false))
        holder.addChild(t)
        if let bg {
            let w = bounds.extents.x + size * 1.1, h = bounds.extents.y + size * 0.7
            let board = ModelEntity(mesh: .generateBox(width: w, height: h, depth: 0.04, cornerRadius: h * 0.45), materials: [unlit(bg)])
            board.components.set(DynamicLightShadowComponent(castsShadow: false))
            holder.addChild(board)
        }
        return holder
    }

    // MARK: Animations

    private func animate(_ e: Entity, to t: Transform, duration: TimeInterval, timing: AnimationTimingFunction = .easeInOut) async {
        e.move(to: t, relativeTo: e.parent, duration: duration, timingFunction: timing)
        try? await Task.sleep(for: .seconds(duration))
        e.transform = t
    }

    func throwDie(showing v: Int) async {
        let base = pawn.position
        let toward = SIMD3<Float>(cos(theta), 0, sin(theta)) * 1.8
        die.position = base + toward + [0, 5.2, 0]
        die.isEnabled = true
        for i in 0..<6 {
            let k = Float(i + 1) / 6
            let axis = simd_normalize(SIMD3<Float>(Float.random(in: -1...1), Float.random(in: 0.2...1), Float.random(in: -1...1)))
            let q = simd_quatf(angle: Float.random(in: 0...(2 * .pi)), axis: axis)
            let p = base + toward + [0, 3.4 + sin(k * .pi) * 1.4 - k * 1.5, 0]
            await animate(die, to: Transform(scale: .one, rotation: q, translation: p), duration: 0.11, timing: .linear)
        }
        await animate(die, to: Transform(scale: .one, rotation: Self.dieRotation(showing: v), translation: base + toward + [0, 1.6, 0]),
                      duration: 0.22, timing: .easeOut)
        try? await Task.sleep(for: .milliseconds(450))
        die.isEnabled = false
    }

    func hopPawn(to c: Cell) async {
        let from = pawn.position, to = Self.position(c, y: Self.streetTop)
        let rot = simd_quatf(angle: atan2(to.x - from.x, to.z - from.z), axis: [0, 1, 0])
        let mid = (from + to) / 2 + [0, 0.75, 0]
        await animate(pawn, to: Transform(scale: pawn.scale, rotation: rot, translation: mid), duration: 0.11, timing: .easeOut)
        await animate(pawn, to: Transform(scale: pawn.scale, rotation: rot, translation: to), duration: 0.11, timing: .easeIn)
    }

    func ridePawn(along path: [Cell]) async {
        let bus = makeBus()
        bus.position = pawn.position
        world.addChild(bus)
        for c in path {
            let to = Self.position(c, y: Self.streetTop)
            let from = bus.position
            let rot = simd_quatf(angle: atan2(to.x - from.x, to.z - from.z), axis: [0, 1, 0])
            bus.move(to: Transform(scale: .one, rotation: rot, translation: to), relativeTo: world, duration: 0.09, timingFunction: .linear)
            pawn.move(to: Transform(scale: pawn.scale, rotation: rot, translation: to + [0, 0.75, 0]), relativeTo: world, duration: 0.09, timingFunction: .linear)
            try? await Task.sleep(for: .milliseconds(90))
        }
        bus.removeFromParent()
        let end = Self.position(path.last ?? Cell(0, 0), y: Self.streetTop)
        await animate(pawn, to: Transform(scale: pawn.scale, rotation: pawn.orientation, translation: end), duration: 0.2, timing: .easeIn)
    }

    func hopGhost(_ id: Int, to c: Cell) async {
        guard let e = ghostEntities[id] else { return }
        let off = ghostOffsets[id] ?? .zero
        let from = e.position, to = Self.position(c, y: Self.streetTop) + off
        let rot = simd_quatf(angle: atan2(to.x - from.x, to.z - from.z), axis: [0, 1, 0])
        await animate(e, to: Transform(scale: e.scale, rotation: rot, translation: (from + to) / 2 + [0, 0.55, 0]), duration: 0.085, timing: .easeOut)
        await animate(e, to: Transform(scale: e.scale, rotation: rot, translation: to), duration: 0.085, timing: .easeIn)
    }

    private func makeBus() -> Entity {
        let g = Entity()
        part(box(0.6, 0.6, 1.7, r: 0.1), 0x14B8C8, [0, 0.42, 0], in: g)
        part(box(0.62, 0.18, 1.5, r: 0.05), 0xDDF3F6, [0, 0.55, 0], in: g)
        part(box(0.6, 0.06, 1.7, r: 0.02), 0xFFFFFF, [0, 0.75, 0], in: g)
        return g
    }

    // MARK: Fork arrows

    func showForkArrows(at c: Cell, dirs: [Dir]) {
        clearForkArrows()
        let colors: [UInt32] = [0xE5533D, 0x3E9D4E, 0x4A90D9]
        for (i, d) in dirs.enumerated() {
            let holder = Entity()
            holder.name = "fork-\(i)"
            let arrow = ModelEntity(mesh: cone(0.9, 0.42), materials: [unlit(colors[i % colors.count])])
            arrow.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
            arrow.components.set(DynamicLightShadowComponent(castsShadow: false))
            holder.addChild(arrow)
            holder.position = Self.position(c, y: 0.9) + SIMD3<Float>(Float(d.dx), 0, Float(d.dy)) * 1.3
            holder.orientation = simd_quatf(angle: atan2(-Float(d.dy), Float(d.dx)), axis: [0, 1, 0])
            holder.generateCollisionShapes(recursive: true)
            arrowRoot.addChild(holder)
        }
    }

    func clearForkArrows() { arrowRoot.children.removeAll() }

    // MARK: Coins and pops

    func addCoin(at c: Cell) {
        guard coinEntities[c] == nil else { return }
        let e = ModelEntity(mesh: cylinder(0.08, 0.32), materials: [SimpleMaterial(color: UIColor(hex: 0xF5C542), roughness: 0.3, isMetallic: true)])
        e.position = Self.position(c, y: 0.95)
        coinRoot.addChild(e)
        coinEntities[c] = e
    }

    func removeCoin(at c: Cell) {
        coinEntities[c]?.removeFromParent()
        coinEntities[c] = nil
    }

    func pop(text: String, at c: Cell, color: UInt32) {
        let e = label(text, size: 0.4, fg: 0x4A2E1B, bg: color)
        e.position = Self.position(c, y: 2.2)
        popRoot.addChild(e)
        var t = e.transform
        t.translation += [0, 1.6, 0]
        e.move(to: t, relativeTo: popRoot, duration: 1.2, timingFunction: .easeOut)
        Task { [weak e] in
            try? await Task.sleep(for: .milliseconds(1250))
            e?.removeFromParent()
        }
    }

    // MARK: Traffic

    private func spawnCars(_ n: Int) {
        let colors: [UInt32] = [0xE5533D, 0xFFFFFF, 0x4A90D9, 0xF5C542, 0x6B4A9E, 0x5DBB63, 0xB8784A]
        let roads = map.roadCells
        for i in 0..<n {
            let g = Entity()
            part(box(0.46, 0.26, 0.9, r: 0.08), colors[i % colors.count], [0, 0.2, 0], in: g)
            part(box(0.4, 0.2, 0.48, r: 0.06), 0xCFE0EE, [0, 0.42, -0.05], in: g)
            trafficRoot.addChild(g)
            let c = roads[(i * 37 + 11) % roads.count]
            let dir = map.options(at: c, heading: .east).first ?? .east
            cars.append(Car(entity: g, cell: c, dir: dir, t: Float.random(in: 0..<1), speed: Float.random(in: 1.2...1.9)))
        }
    }

    private func updateCars(_ dt: Float) {
        for i in cars.indices {
            var car = cars[i]
            car.t += dt * car.speed / Self.cell * 2
            while car.t >= 1 {
                car.t -= 1
                car.cell = car.cell.moved(car.dir)
                if !map.isRoad(car.cell.moved(car.dir)) || map.isIntersection(car.cell) {
                    let o = map.options(at: car.cell, heading: car.dir)
                    car.dir = o.randomElement() ?? car.dir.reversed
                }
            }
            let a = Self.position(car.cell, y: Self.streetTop), b = Self.position(car.cell.moved(car.dir), y: Self.streetTop)
            let lane = SIMD3<Float>(-Float(car.dir.dy), 0, Float(car.dir.dx)) * 0.5
            car.entity.position = a + (b - a) * car.t + lane
            car.entity.orientation = yaw(car.dir)
            cars[i] = car
        }
    }

    // MARK: Camera

    func focusOnPawn() { followPawn = true; goalDistance = 26 }
    func focusOnMyBlocks() {
        followPawn = false
        let bs = map.myBlocks
        guard !bs.isEmpty else { return }
        var sum = SIMD3<Float>(0, 0, 0)
        for b in bs { sum += Self.position(CityMap.blockOrigin(b)) + [5, 0, 5] }
        goalTarget = sum / Float(bs.count)
        goalDistance = bs.count > 1 ? 38 : 30
    }
    func focusOnCity() { followPawn = false; goalTarget = .zero; goalDistance = 92 }

    func orbit(by translation: CGPoint) {
        theta += Float(translation.x) * 0.006
        phi = max(0.35, min(1.3, phi - Float(translation.y) * 0.005))
    }

    func zoom(by scale: CGFloat) {
        goalDistance = max(10, min(130, goalDistance / Float(scale)))
    }

    func handleTap(at point: CGPoint) {
        var e = arView.entity(at: point)
        while let cur = e {
            if cur.name.hasPrefix("fork-"), let i = Int(cur.name.dropFirst(5)) { onTapFork?(i); return }
            if cur.name.hasPrefix("sale-"), let b = Int(cur.name.dropFirst(5)) { onTapSale?(b); return }
            e = cur.parent
        }
    }

    private func update(dt: Float) {
        clock += dt
        if followPawn { goalTarget = pawn.position * SIMD3<Float>(1, 0, 1) }
        let k = min(1, dt * 5), kd = min(1, dt * 4)
        target += (goalTarget - target) * k
        distance += (goalDistance - distance) * kd
        let eye = target + SIMD3<Float>(cos(theta) * sin(phi), cos(phi), sin(theta) * sin(phi)) * distance
        camera.look(at: target, from: eye, relativeTo: nil)

        for (i, e) in coinRoot.children.enumerated() {
            e.orientation = simd_quatf(angle: clock * 2.2 + Float(i), axis: [0, 1, 0]) * simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        }
        for e in arrowRoot.children {
            e.position.y = 0.9 + sin(clock * 5.5) * 0.12
        }
        updateCars(dt)
    }
}
