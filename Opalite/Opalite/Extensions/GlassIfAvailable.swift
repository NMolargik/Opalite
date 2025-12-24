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
            content
        }
    }

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *)
    @ViewBuilder
    private func applyGlass(to content: Content) -> some View {
        switch configuration.style {
        case .clear:
            if configuration.isInteractive {
                if let tint = configuration.tint {
                    content.glassEffect(.clear.tint(tint).interactive())
                } else {
                    content.glassEffect(.clear.interactive())
                }
            } else {
                if let tint = configuration.tint {
                    content.glassEffect(.clear.tint(tint))
                } else {
                    content.glassEffect(.clear)
                }
            }

        case .regular:
            if configuration.isInteractive {
                if let tint = configuration.tint {
                    content.glassEffect(.regular.tint(tint).interactive())
                } else {
                    content.glassEffect(.regular.interactive())
                }
            } else {
                if let tint = configuration.tint {
                    content.glassEffect(.regular.tint(tint))
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
}
