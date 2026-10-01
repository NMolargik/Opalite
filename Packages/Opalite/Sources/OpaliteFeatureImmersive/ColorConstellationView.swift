//
//  ColorConstellationView.swift
//  OpaliteFeatureImmersive
//
//  The visionOS immersive space that wraps the viewer in color. Single color: an enveloping
//  sphere in the hero color with its harmonies floating as orbs ahead. Palette: a ring of
//  tall panels, capped top and bottom, drifting slowly past.
//

#if os(visionOS)
import SwiftUI
import RealityKit
import UIKit
import os
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

/// Reads `ImmersiveColorModel` from the environment. Open it with `openImmersiveSpace`
/// after calling one of the model's `prepare…` methods.
public struct ColorConstellationView: View {
    @Environment(ImmersiveColorModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var root = Entity()
    @State private var ring = Entity()
    @State private var orbs: [Entity] = []

    public init() {}

    public var body: some View {
        RealityView { content in
            content.add(root)
            rebuild()
        }
        .onAppear { model.isImmersed = true }
        .onDisappear { model.isImmersed = false }
        .onChange(of: model.colors) { rebuild() }
        .onChange(of: model.mode) { rebuild() }
        .task(id: motionKey) { await animate() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityDescription))
    }

    private var motionKey: String { "\(model.mode)-\(reduceMotion)-\(model.colors.count)" }

    private var accessibilityDescription: String {
        switch model.mode {
        case .singleColor:
            if let hero = model.heroColor {
                return String(localized: "Immersed in \(hero.hexString) with \(model.harmonyColors.count) harmony colors floating ahead")
            }
            return String(localized: "Empty immersive space")
        case .palette:
            return String(localized: "Surrounded by \(model.colors.count) palette colors")
        }
    }

    // MARK: - Scene construction

    private func rebuild() {
        root.children.removeAll()
        ring = Entity()
        orbs = []
        guard model.hasContent else { return }

        switch model.mode {
        case .singleColor: buildSingleColor()
        case .palette: buildPalette()
        }
        Log.app.debug("Immersive scene rebuilt: \(String(describing: model.mode)) with \(model.colors.count) colors")
    }

    /// An inverted sphere so the viewer sits inside the hero color, plus harmony orbs.
    private func buildSingleColor() {
        guard let hero = model.heroColor else { return }

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: ImmersiveSceneLayout.sphereRadius),
            materials: [material(hero)]
        )
        sphere.scale = SIMD3(-1, 1, 1) // render the inside faces
        sphere.position = SIMD3(0, ImmersiveSceneLayout.eyeHeight, 0)
        sphere.name = "environment"
        root.addChild(sphere)

        let harmonies = model.harmonyColors
        for (index, color) in harmonies.enumerated() {
            let orb = ModelEntity(
                mesh: .generateSphere(radius: ImmersiveSceneLayout.orbRadius),
                materials: [material(color)]
            )
            orb.position = ImmersiveSceneLayout.orbPosition(index: index, count: harmonies.count)
            orb.name = "orb_\(index)"
            root.addChild(orb)
            orbs.append(orb)
        }
    }

    /// A full ring of inward-facing panels, with floor and ceiling caps in the mean color.
    private func buildPalette() {
        let colors = model.colors
        let count = colors.count
        let width = ImmersiveSceneLayout.panelWidth(count: count)
        let center = SIMD3<Float>(0, ImmersiveSceneLayout.eyeHeight, 0)

        for (index, color) in colors.enumerated() {
            let panel = ModelEntity(
                mesh: .generatePlane(width: width, height: ImmersiveSceneLayout.panelHeight),
                materials: [material(color)]
            )
            panel.position = ImmersiveSceneLayout.panelPosition(index: index, count: count)
            panel.look(at: center, from: panel.position, relativeTo: nil)
            panel.name = "panel_\(index)"
            ring.addChild(panel)
        }

        let capMaterial = material(ImmersiveSceneLayout.average(colors))
        let side = ImmersiveSceneLayout.capSide()

        let floor = ModelEntity(mesh: .generatePlane(width: side, depth: side), materials: [capMaterial])
        floor.position = SIMD3(0, ImmersiveSceneLayout.floorHeight, 0)
        floor.name = "floor"
        ring.addChild(floor)

        let ceiling = ModelEntity(mesh: .generatePlane(width: side, depth: side), materials: [capMaterial])
        ceiling.position = SIMD3(0, ImmersiveSceneLayout.ceilingHeight, 0)
        ceiling.orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
        ceiling.name = "ceiling"
        ring.addChild(ceiling)

        root.addChild(ring)
    }

    /// Unlit so the color is shown exactly, double-sided so panels read from either face.
    private func material(_ rgba: RGBA) -> UnlitMaterial {
        var material = UnlitMaterial(color: rgba.uiColor)
        material.faceCulling = .none
        return material
    }

    // MARK: - Motion

    /// Drifts the palette ring (one revolution a minute) and bobs the harmony orbs.
    /// Honors Reduce Motion by leaving the scene still.
    private func animate() async {
        guard !reduceMotion, model.hasContent else { return }
        let clock = ContinuousClock()
        let start = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(33))
            guard !Task.isCancelled else { return }
            let elapsed = start.duration(to: clock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            apply(time: seconds)
        }
    }

    private func apply(time: Double) {
        switch model.mode {
        case .palette:
            ring.orientation = simd_quatf(angle: ImmersiveSceneLayout.rotationAngle(at: time), axis: SIMD3(0, 1, 0))
        case .singleColor:
            for (index, orb) in orbs.enumerated() {
                let base = ImmersiveSceneLayout.orbPosition(index: index, count: orbs.count)
                orb.position = SIMD3(base.x, base.y + ImmersiveSceneLayout.bobOffset(at: time, index: index), base.z)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Palette ring", immersionStyle: .full) {
    let model = ImmersiveColorModel()
    model.prepareForPalette(OpalitePalette.sample.colorValues)
    return ColorConstellationView()
        .environment(model)
        .previewEnvironment()
}

#Preview("Single color", immersionStyle: .full) {
    let model = ImmersiveColorModel()
    model.prepareForSingleColor(OpaliteColor.sample.rgba)
    return ColorConstellationView()
        .environment(model)
        .previewEnvironment()
}
#endif
#endif
