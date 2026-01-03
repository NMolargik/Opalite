//
//  ContentView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/6/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager
    @Environment(QuickActionManager.self) private var quickActionManager: QuickActionManager
    @Environment(HexCopyManager.self) private var hexCopyManager: HexCopyManager
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false

    @State private var appStage: AppStage = .splash
    @State private var isShowingPaywall: Bool = false
    @State private var paywallContext: String = ""
    @State private var isColorBlindnessBannerVisible: Bool = true

    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw: String = AppThemeOption.system.rawValue
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var colorBlindnessMode: ColorBlindnessMode {
        ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off
    }

    private var preferredColorScheme: ColorScheme? {
        let option = AppThemeOption(rawValue: appThemeRaw) ?? .system
        switch option {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var leadingTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    var body: some View {
        ZStack {
            switch appStage {
            case .splash:
                SplashView(
                    onContinue: {
                        withAnimation {
                            appStage = .onboarding
                        }
                    }
                )
                .id("splash")
                .transition(leadingTransition)
                .zIndex(1)
                .preferredColorScheme(.dark)
                .accessibilityIdentifier("splashView")
            case .onboarding:
                OnboardingView(
                    onContinue: {
                        withAnimation {
                            appStage = .main
                        }
                    }
                )
                .environment(colorManager)
                .environment(canvasManager)
                .id("onboarding")
                .transition(leadingTransition)
                .zIndex(1)
                .preferredColorScheme(preferredColorScheme)
                .accessibilityIdentifier("onboardingView")
            case .main:
                MainView()
                .environment(colorManager)
                .environment(canvasManager)
                .id("main")
                .transition(leadingTransition)
                .zIndex(0)
                .preferredColorScheme(preferredColorScheme)
                .accessibilityIdentifier("mainView")
                .safeAreaInset(edge: .top) {
                    if colorBlindnessMode != .off && isColorBlindnessBannerVisible {
                        ColorBlindnessBannerView(mode: colorBlindnessMode) {
                            withAnimation(.easeInOut) {
                                isColorBlindnessBannerVisible = false
                            }
                        }
                    }
                }
                .onChange(of: colorBlindnessMode) { oldValue, newValue in
                    if newValue != .off {
                        isColorBlindnessBannerVisible = true
                    }
                }
            }
        }
        .task {
            await prepareApp()
        }
        .onAppear {
            colorManager.isMainWindowOpen = true
            #if os(iOS)
            AppDelegate.registerMainSceneSession()
            #endif
        }
        .onDisappear {
            colorManager.isMainWindowOpen = false
            #if os(iOS)
            AppDelegate.mainSceneSession = nil
            #endif
        }
        .onChange(of: quickActionManager.paywallTrigger?.id) { _, _ in
            if let trigger = quickActionManager.paywallTrigger {
                paywallContext = trigger.context
                isShowingPaywall = true
                quickActionManager.paywallTrigger = nil
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: paywallContext)
        }
    }
    
    private func prepareApp() async {
        await colorManager.refreshAll()
        await canvasManager.refreshAll()
        appStage = isOnboardingComplete ? .main : .splash
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: OpaliteColor.self, OpalitePalette.self, CanvasFile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let colorManager = ColorManager(context: container.mainContext)
    let canvasManager = CanvasManager(context: container.mainContext)
    return ContentView()
        .modelContainer(container)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(SubscriptionManager())
        .environment(ToastManager())
        .environment(QuickActionManager())
        .environment(HexCopyManager())
}

