//
//  GlassIfAvailable.swift
//  Opalite
//
//  Created by Nick Molargik on 12/24/25.
//

import SwiftUI

/// A configuration object that mirrors the fluent GlassEffect API
/// (e.g. `.clear.tint(.blue).interactive()`)
struct GlassConfiguration {
    enum Style {
        case clear
        case regular
    }

    var style: Style = .clear
    var tint: Color?
    var isInteractive: Bool = false

    func tint(_ color: Color) -> GlassConfiguration {
        var copy = self
        copy.tint = color
        return copy
    }

    func interactive(_ enabled: Bool = true) -> GlassConfiguration {
        var copy = self
        copy.isInteractive = enabled
        return copy
    }
}

struct GlassIfAvailable: ViewModifier {
    let configuration: GlassConfiguration

    init(configuration: GlassConfiguration = .init()) {
        self.configuration = configuration
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *) {
            applyGlass(to: content)
        } else {
            applyFallback(to: content)
        }
    }

    @ViewBuilder
    private func applyFallback(to content: Content) -> some View {
        if let tint = configuration.tint {
            // Solid tinted background when a tint is specified
            content.background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            // Material background when no tint
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *)
    @ViewBuilder
    private func applyGlass(to content: Content) -> some View {
        // If a tint is provided, use solid background instead of glass
        if let tint = configuration.tint {
            content.background(tint.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            switch configuration.style {
            case .clear:
                if configuration.isInteractive {
                    content.glassEffect(.clear.interactive())
                } else {
                    content.glassEffect(.clear)
                }

            case .regular:
                if configuration.isInteractive {
                    content.glassEffect(.regular.interactive())
                } else {
                    content.glassEffect(.regular)
                }
            }
        }
    }
}

extension View {
    func glassIfAvailable(_ configuration: GlassConfiguration = .init()) -> some View {
        modifier(GlassIfAvailable(configuration: configuration))
    }

    /// Applies inverse theme tint to toolbar buttons on OS versions below 26.
    /// On iOS 26+, toolbar buttons automatically get appropriate styling.
    @ViewBuilder
    func toolbarButtonTint() -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *) {
            self
        } else {
            self.tint(Color("inverseTheme"))
        }
    }
}
