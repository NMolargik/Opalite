//
//  ViewModifiers.swift
//  OpaliteDesignSystem
//
//  The shared building blocks of the HIG / Liquid Glass surface language: glass and
//  material surfaces, the standard action buttons, OS-gated chrome helpers, hover
//  affordances, and small conditionals. Everything that needs an iOS 26+ / 27+ API is
//  gated here once so feature code stays free of `#available`.
//

import SwiftUI
import OpaliteCore
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Glass

extension View {
    /// Liquid Glass (iOS/iPadOS/macOS/tvOS 26+) with an optional tint; a material
    /// rounded rectangle elsewhere (visionOS uses its own glass, so it gets the material).
    @ContentBuilder
    public func adaptiveGlass(tint: Color? = nil, interactive: Bool = false, cornerRadius: CGFloat = Brand.Radius.control) -> some View {
        #if os(visionOS) || os(watchOS)
        materialSurface(tint: tint, cornerRadius: cornerRadius)
        #else
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            if let tint {
                if interactive {
                    glassEffect(.regular.tint(tint.opacity(0.55)).interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    glassEffect(.regular.tint(tint.opacity(0.55)), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            } else if interactive {
                glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            materialSurface(tint: tint, cornerRadius: cornerRadius)
        }
        #endif
    }

    /// A capsule-shaped glass (toasts, pills).
    @ContentBuilder
    public func adaptiveGlassCapsule(tint: Color? = nil) -> some View {
        #if os(visionOS) || os(watchOS)
        background(Capsule(style: .continuous).fill(.ultraThinMaterial))
            .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
        #else
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            if let tint {
                glassEffect(.regular.tint(tint.opacity(0.45)).interactive(), in: Capsule(style: .continuous))
            } else {
                glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
            }
        } else {
            background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        #endif
    }

    /// The pre-26 fallback and the visionOS surface: thin material with a hairline.
    public func materialSurface(tint: Color? = nil, cornerRadius: CGFloat = Brand.Radius.control) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(.ultraThinMaterial)
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(tint.opacity(0.18))
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.quaternary))
    }

    /// The standard card surface — material fill, hairline border, soft shadow — without
    /// padding, for views that manage their own internal spacing.
    public func cardSurface(cornerRadius: CGFloat = Brand.Radius.card) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.quaternary))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    /// Standard card styling: padded content on the shared card surface.
    public func cardStyle(cornerRadius: CGFloat = Brand.Radius.card) -> some View {
        padding(Brand.Space.lg).cardSurface(cornerRadius: cornerRadius)
    }

    /// Conditionally applies a transform — keeps call sites declarative.
    @ContentBuilder
    public func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition { transform(self) } else { self }
    }

    /// Pointer/hover highlight for iPad trackpads and Mac — a no-op elsewhere.
    @ContentBuilder
    public func hoverHighlight() -> some View {
        #if os(iOS) || os(visionOS)
        hoverEffect(.highlight)
        #else
        self
        #endif
    }

    /// Pointer lift for card-like tappable surfaces.
    @ContentBuilder
    public func hoverLift() -> some View {
        #if os(iOS) || os(visionOS)
        hoverEffect(.lift)
        #else
        self
        #endif
    }

    /// Material pill background for compact stat chips.
    public func statPillBackground() -> some View {
        background(Capsule(style: .continuous).fill(.ultraThinMaterial))
            .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
    }

    /// Tints toolbar glyphs with the inverse-theme color on systems before 26, where
    /// toolbar buttons otherwise pick up the accent color.
    @ContentBuilder
    public func toolbarButtonTint() -> some View {
        #if os(visionOS) || os(watchOS)
        self
        #else
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            self
        } else {
            tint(.opaliteInverse)
        }
        #endif
    }
}

// MARK: - Buttons

extension View {
    /// The app's standard action-button treatment: native Liquid Glass button styles on
    /// 26+ (bordered fallback). Reserve `prominent` for the single primary action in a
    /// given context.
    ///
    /// Brand tints are remapped for legibility: a prominent button fills with the tint's
    /// `fillVariant` (white text reads on it in either appearance) and a plain one labels
    /// with its `inkVariant` (deep in light mode, the pale brand color in dark mode).
    @ContentBuilder
    public func glassActionButton(tint: Color = .opalitePurple, prominent: Bool = true) -> some View {
        #if os(visionOS) || os(watchOS)
        if prominent { buttonStyle(.borderedProminent).tint(tint.fillVariant) } else { buttonStyle(.bordered).tint(tint.inkVariant) }
        #else
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent).tint(tint.fillVariant) } else { buttonStyle(.glass).tint(tint.inkVariant) }
        } else {
            if prominent { buttonStyle(.borderedProminent).tint(tint.fillVariant) } else { buttonStyle(.bordered).tint(tint.inkVariant) }
        }
        #endif
    }

    /// The full-width primary call to action (onboarding, paywall, empty states).
    public func primaryActionButton(tint: Color = .opalitePurple) -> some View {
        glassActionButton(tint: tint, prominent: true)
            .controlSize(.large)
            .frame(maxWidth: Brand.readableWidth)
            .hoverHighlight()
    }

    /// The full-width secondary call to action next to a primary one.
    public func secondaryActionButton(tint: Color = .opaliteBlue) -> some View {
        glassActionButton(tint: tint, prominent: false)
            .controlSize(.large)
            .frame(maxWidth: Brand.readableWidth)
            .hoverHighlight()
    }
}

// MARK: - OS-gated navigation chrome

extension View {
    /// Lets the tab bar collapse while scrolling down (iOS 26+).
    @ContentBuilder
    public func minimizeTabBarOnScrollIfAvailable() -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Lets the search field minimize into the toolbar (iOS 26+).
    @ContentBuilder
    public func minimizingSearchIfAvailable() -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *) {
            searchToolbarBehavior(.minimize)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Soft scroll-edge effect under glass bars (26+), hard edge otherwise.
    @ContentBuilder
    public func softScrollEdgesIfAvailable() -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 26.0, macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Lets a hero image extend under the glass navigation bar (iOS 26+).
    @ContentBuilder
    public func backgroundExtensionIfAvailable() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            backgroundExtensionEffect()
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// A navigation subtitle under the large title (iOS 26+), ignored elsewhere.
    @ContentBuilder
    public func navigationSubtitleIfAvailable(_ subtitle: String) -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 26.0, macOS 26.0, *) {
            navigationSubtitle(subtitle)
        } else {
            self
        }
        #else
        self
        #endif
    }

}

// MARK: - Menus

extension View {
    /// Keeps a destructive menu item's glyph red next to its red title. Menu glyphs pick
    /// up the nearest `tint` (the tab color), which otherwise leaves a blue trash can
    /// beside red text.
    public func destructiveMenuItem() -> some View {
        tint(.red)
    }
}

// MARK: - Keyboard

public enum Keyboard {
    /// Resigns the software keyboard from whichever field holds focus — the keyboard
    /// toolbar's Done button, and the escape hatch for number pads with no return key.
    @MainActor
    public static func dismiss() {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Label styles

/// A label whose icon sits in a fixed-width column so stacked rows align.
public struct AlignedIconLabelStyle: LabelStyle {
    let width: CGFloat

    public init(width: CGFloat = 28) { self.width = width }

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Brand.Space.md) {
            configuration.icon.frame(width: width, alignment: .center)
            configuration.title
        }
    }
}

extension LabelStyle where Self == AlignedIconLabelStyle {
    public static var alignedIcon: AlignedIconLabelStyle { AlignedIconLabelStyle() }
}

/// The iOS-Settings idiom: a white glyph on a tinted rounded square, then the title.
public struct SettingsIconLabelStyle: LabelStyle {
    let tint: Color

    public init(tint: Color) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Brand.Space.md) {
            configuration.icon
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.gradient))
                .accessibilityHidden(true)
            configuration.title.foregroundStyle(.primary)
        }
    }
}

extension LabelStyle where Self == SettingsIconLabelStyle {
    /// `Label("Appearance", systemImage: "paintbrush").labelStyle(.settingsIcon(.indigo))`
    public static func settingsIcon(_ tint: Color) -> SettingsIconLabelStyle { SettingsIconLabelStyle(tint: tint) }
}

// MARK: - Platform backgrounds

/// The platform's grouped background (forms, onboarding pages).
public var groupedBackground: Color {
    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    Color(uiColor: .systemGroupedBackground)
    #else
    Color.gray.opacity(0.1)
    #endif
}

/// The platform's secondary grouped background (cards inside grouped pages).
public var secondaryGroupedBackground: Color {
    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    Color(uiColor: .secondarySystemGroupedBackground)
    #else
    Color.gray.opacity(0.15)
    #endif
}

public var secondaryBackground: Color {
    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    Color(uiColor: .secondarySystemBackground)
    #else
    Color.gray.opacity(0.15)
    #endif
}
