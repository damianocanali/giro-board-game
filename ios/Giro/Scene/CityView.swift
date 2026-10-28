import SwiftUI
import RealityKit
import UIKit

/// Hosts the RealityKit city and forwards touches (orbit, zoom, taps on fork arrows / for-sale signs).
struct CityView: UIViewRepresentable {
    let model: GameModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let scene = CityScene(map: model.map)
        scene.setup(map: model.map, pawnAt: model.player.position, heading: model.player.heading,
                    skin: model.player.skin, pickups: model.pickups, ghosts: model.ghosts)
        scene.onTapFork = { [weak model] i in model?.pickFork(i) }
        scene.onTapSale = { [weak model] b in
            guard let model, !model.isBusy, model.saleOffer == nil else { return }
            Task { await model.offerSaleFromSign(b) }
        }
        scene.onTapCell = { [weak model] c in model?.paint(c) }
        model.scene = scene
        if model.showMenu { scene.setShowcase(true) }
        context.coordinator.scene = scene

        let view = scene.arView
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        [pan, pinch, tap].forEach { view.addGestureRecognizer($0) }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject {
        /// Strong on purpose: the coordinator lives as long as the view, and it is the scene's only owner
        /// (GameModel holds it weakly). With a weak reference here the scene was freed right after creation.
        var scene: CityScene?
        private var lastPan: CGPoint = .zero
        private var lastScale: CGFloat = 1

        @objc func pan(_ g: UIPanGestureRecognizer) {
            let t = g.translation(in: g.view)
            if g.state == .began { lastPan = .zero }
            scene?.orbit(by: CGPoint(x: t.x - lastPan.x, y: t.y - lastPan.y))
            lastPan = t
        }

        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            if g.state == .began { lastScale = 1 }
            scene?.zoom(by: g.scale / lastScale)
            lastScale = g.scale
        }

        @objc func tap(_ g: UITapGestureRecognizer) {
            scene?.handleTap(at: g.location(in: g.view))
        }
    }
}
