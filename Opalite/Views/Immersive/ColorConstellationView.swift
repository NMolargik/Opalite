//
//  ColorConstellationView.swift
//  Opalite
//
//  Created by Nick Molargik on 2/12/26.
//

#if os(visionOS)
import SwiftUI
import RealityKit

/// Immersive space that wraps the user's entire view in color.
///
/// Single color mode: a large inverted sphere surrounds the user in the color
/// with a gentle brightness pulse. Palette mode: tall color panels arranged
/// in a full ring so the user is enclosed in all palette colors at once.
struct ColorConstellationView: View {
    @Environment(ImmersiveColorManager.self) private var immersiveManager

    @State private var rootEntity = Entity()
    @State private var animationTime: Double = 0
    @State private var timer: Timer?

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            buildScene()
        }
        .onAppear {
            immersiveManager.isImmersed = true
            startAnimationTimer()
        }
        .onDisappear {
            stopAnimationTimer()
            immersiveManager.isImmersed = false
        }
    }

    // MARK: - Scene Construction

    private func buildScene() {
        rootEntity.children.removeAll()

        let colors = immersiveManager.colors
        guard !colors.isEmpty else { return }

        switch immersiveManager.mode {
        case .singleColor:
            buildSingleColorEnvironment(colors: colors)
        case .palette:
            buildPaletteEnvironment(colors: colors)
        }
    }

    // MARK: - Single Color: Surrounding Sphere

    /// Creates a large inverted sphere that envelops the user in the color.
    private func buildSingleColorEnvironment(colors: [ImmersiveColorData]) {
        guard let hero = colors.first else { return }

        let mesh = MeshResource.generateSphere(radius: 50)
        var material = UnlitMaterial(color: uiColor(from: hero))

        let sphere = ModelEntity(mesh: mesh, materials: [material])
        // Flip to render inside faces — puts the user inside the color
        sphere.scale = .init(x: -1, y: 1, z: 1)
        sphere.position = .init(x: 0, y: 1.5, z: 0)
        sphere.name = "environment"
        rootEntity.addChild(sphere)
    }

    // MARK: - Palette: Color Panel Ring

    /// Arranges tall color panels in a full ring around the user,
    /// so every direction they look shows a palette color.
    private func buildPaletteEnvironment(colors: [ImmersiveColorData]) {
        let count = colors.count
        guard count > 0 else { return }

        let ringRadius: Float = 5.0
        let panelHeight: Float = 10.0
        // Each panel spans an equal slice of the full circle
        let anglePerPanel = (2 * Float.pi) / Float(count)
        // Make panels slightly wider than the arc they cover to eliminate gaps
        let panelWidth = 2 * ringRadius * sin(anglePerPanel / 2) + 0.02

        for (index, colorData) in colors.enumerated() {
            let angle = anglePerPanel * Float(index)

            var material = UnlitMaterial(color: uiColor(from: colorData))

            let panel = ModelEntity(
                mesh: .generatePlane(width: panelWidth, height: panelHeight),
                materials: [material]
            )

            // Position on the ring at eye level
            let x = sin(angle) * ringRadius
            let z = -cos(angle) * ringRadius
            panel.position = .init(x: x, y: 1.5, z: z)

            // Face inward toward the user at the center
            let centerTarget: SIMD3<Float> = .init(x: 0, y: 1.5, z: 0)
            panel.look(at: centerTarget, from: panel.position, relativeTo: nil)

            panel.name = "panel_\(index)"
            rootEntity.addChild(panel)
        }

        // Floor and ceiling in a blended average color to complete the enclosure
        let avgColor = averageColor(colors)
        let capMaterial = UnlitMaterial(color: avgColor)

        let floor = ModelEntity(
            mesh: .generatePlane(width: ringRadius * 2.5, height: ringRadius * 2.5),
            materials: [capMaterial]
        )
        floor.position = .init(x: 0, y: 1.5 - panelHeight / 2, z: 0)
        floor.orientation = simd_quatf(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0))
        floor.name = "floor"
        rootEntity.addChild(floor)

        let ceiling = ModelEntity(
            mesh: .generatePlane(width: ringRadius * 2.5, height: ringRadius * 2.5),
            materials: [capMaterial]
        )
        ceiling.position = .init(x: 0, y: 1.5 + panelHeight / 2, z: 0)
        ceiling.orientation = simd_quatf(angle: .pi / 2, axis: .init(x: 1, y: 0, z: 0))
        ceiling.name = "ceiling"
        rootEntity.addChild(ceiling)
    }

    // MARK: - Animation

    private func startAnimationTimer() {
        guard immersiveManager.mode == .palette else { return }
        // Slow rotation for palette mode so the colors drift past
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                animationTime += 1.0 / 30.0
                applyRotation()
            }
        }
    }

    private func stopAnimationTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Very slow rotation of the palette ring (~60 seconds per revolution)
    private func applyRotation() {
        let rotationSpeed: Float = (2 * .pi) / 60.0 // Full revolution in 60s
        let angle = Float(animationTime) * rotationSpeed
        rootEntity.orientation = simd_quatf(angle: angle, axis: .init(x: 0, y: 1, z: 0))
    }

    // MARK: - Helpers

    private func uiColor(from data: ImmersiveColorData) -> UIColor {
        UIColor(red: data.red, green: data.green, blue: data.blue, alpha: 1.0)
    }

    private func averageColor(_ colors: [ImmersiveColorData]) -> UIColor {
        let count = Double(colors.count)
        let r = colors.reduce(0.0) { $0 + $1.red } / count
        let g = colors.reduce(0.0) { $0 + $1.green } / count
        let b = colors.reduce(0.0) { $0 + $1.blue } / count
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

#endif
