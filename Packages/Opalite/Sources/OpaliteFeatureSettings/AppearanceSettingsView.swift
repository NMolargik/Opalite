//
//  AppearanceSettingsView.swift
//  OpaliteFeatureSettings
//
//  Theme (system / light / dark) and, on iPhone and iPad, the alternate app icon. Both
//  persist through `@AppStorage`; the shell applies the theme, this page applies the icon.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import os
#if canImport(UIKit)
import UIKit
#endif

struct AppearanceSettingsView: View {
    @Environment(ToastManager.self) private var toast
    @AppStorage(AppStorageKeys.appTheme) private var themeRaw = AppThemeOption.system.rawValue
    @AppStorage(AppStorageKeys.appIcon) private var appIconRaw = AppIconOption.dark.rawValue

    private var theme: Binding<AppThemeOption> {
        Binding(
            get: { AppThemeOption(rawValue: themeRaw) ?? .system },
            set: { themeRaw = $0.rawValue }
        )
    }

    private var appIcon: AppIconOption { AppIconOption(rawValue: appIconRaw) ?? .dark }

    var body: some View {
        Form {
            #if !os(visionOS)
            Section {
                Picker("Theme", selection: theme) {
                    ForEach(AppThemeOption.allCases) { option in
                        Label(option.title, systemImage: Self.symbol(for: option))
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: themeRaw) { Haptics.selection() }
                .accessibilityIdentifier("appearance.theme")
            } header: {
                Text("Theme")
            } footer: {
                Text("System follows the appearance of your device. Light and Dark keep Opalite the same regardless.")
            }
            #endif

            #if os(iOS) && !targetEnvironment(macCatalyst)
            if UIApplication.shared.supportsAlternateIcons {
                Section {
                    HStack(spacing: Brand.Space.lg) {
                        ForEach(AppIconOption.allCases) { option in
                            AppIconChoice(option: option, isSelected: option == appIcon) {
                                select(option)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Brand.Space.sm)
                } header: {
                    Text("App Icon")
                } footer: {
                    Text("Choose the icon shown on your Home Screen.")
                }
            }
            #endif
        }
        .navigationTitle("Appearance")
    }

    private static func symbol(for option: AppThemeOption) -> String {
        switch option {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    private func select(_ option: AppIconOption) {
        Haptics.selection()
        appIconRaw = option.rawValue
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != option.iconName else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.iconName)
            } catch {
                Log.app.error("Failed to set app icon: \(error.localizedDescription)")
                toast.show(error: error)
            }
        }
    }
    #endif
}

// MARK: - Icon choice

/// A stylized preview of one app icon with a selection ring; the catalog's icon art
/// isn't visible to the package, so this draws the brand treatment instead.
private struct AppIconChoice: View {
    let option: AppIconOption
    let isSelected: Bool
    let onSelect: () -> Void

    @ScaledMetric(relativeTo: .title) private var side: CGFloat = 72

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: Brand.Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                        .fill(option == .dark ? AnyShapeStyle(LinearGradient.onyx) : AnyShapeStyle(Color.white))
                    Image(systemName: "diamond.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(side * 0.26)
                        .foregroundStyle(LinearGradient.opalite)
                }
                .frame(width: side, height: side)
                .overlay(
                    RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                        .strokeBorder(isSelected ? AnyShapeStyle(LinearGradient.opaliteHorizontal) : AnyShapeStyle(Color.secondary.opacity(0.25)), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.opalitePurple)
                            .accessibilityHidden(true)
                    }
                    Text(option.title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverLift()
        .accessibilityLabel(Text("\(option.title) icon"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("appearance.icon.\(option.rawValue)")
    }
}

#if DEBUG
#Preview("Appearance") {
    NavigationStack { AppearanceSettingsView() }
        .settingsPreviewEnvironment()
}
#endif
#endif
