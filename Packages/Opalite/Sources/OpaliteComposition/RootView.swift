//
//  RootView.swift
//  OpaliteComposition
//
//  The stage machine (splash → onboarding → main), successor to the old ContentView.
//  Injects every shared @Observable model into the environment so feature views read
//  them without knowing the composition root, applies the theme preference, and hosts
//  the toasts.
//

import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteServices
#if os(iOS) || os(visionOS)
import OpaliteFeatureOnboarding

public struct RootView: View {
    private let session: SessionController

    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete = false
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw = AppThemeOption.system.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appStage: AppStage = .splash
    @State private var didShowSyncToast = false
    @State private var wasReturningUser = false

    public init(session: SessionController) {
        self.session = session
    }

    private var theme: AppThemeOption { AppThemeOption(rawValue: appThemeRaw) ?? .system }

    public var body: some View {
        stageView
            .preferredColorScheme(theme.preferredColorScheme)
            .toastContainer()
            .sessionEnvironment(session)
    }

    private var stageView: some View {
        ZStack {
            switch appStage {
            case .splash:
                SplashView(onContinue: { advance(to: .onboarding) })
                    .id("splash")
                    .transition(stageTransition)
                    .zIndex(1)
                    .accessibilityIdentifier("splashView")
            case .onboarding:
                OnboardingView(onFinished: {
                    isOnboardingComplete = true
                    advance(to: .main)
                })
                .id("onboarding")
                .transition(stageTransition)
                .zIndex(1)
                .accessibilityIdentifier("onboardingView")
            case .main:
                MainView(session: session)
                    .id("main")
                    .transition(stageTransition)
                    .zIndex(0)
                    .onAppear(perform: handleMainEntry)
                    .accessibilityIdentifier("mainView")
            }
        }
        .task {
            if CommandLine.arguments.contains("--reset-onboarding") { isOnboardingComplete = false }
            if CommandLine.arguments.contains("--skip-onboarding") { isOnboardingComplete = true }
            wasReturningUser = isOnboardingComplete
            appStage = isOnboardingComplete ? .main : .splash
        }
    }

    private var stageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance(to stage: AppStage) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { appStage = stage }
    }

    /// iCloud sync runs in the background: returning users with iCloud get a lightweight
    /// toast instead of a blocking screen, and the models refresh in case the first
    /// remote import landed before they existed.
    private func handleMainEntry() {
        guard !didShowSyncToast, wasReturningUser, session.cloudSync.isCloudAvailable else { return }
        didShowSyncToast = true
        session.toastManager.show(message: String(localized: "Syncing with iCloud…"), style: .info, systemImage: "icloud.fill")
        session.portfolio.refresh()
        session.canvases.refresh()
    }
}
#endif

// MARK: - Environment injection

extension View {
    /// Injects every shared model the features read.
    @MainActor
    public func sessionEnvironment(_ session: SessionController) -> some View {
        let base = self
            .environment(session.router)
            .environment(session.toastManager)
            .environment(session.portfolio)
            .environment(session.canvases)
            .environment(session.community)
            .environment(session.hexCopy)
            .environment(session.importer)
            .environment(session.cloudSync)
            .environment(session.subscriptions)
            .environment(session.colorNaming)
            .environment(\.onyxEntitlement, session.subscriptions)
        #if os(iOS) && canImport(WatchConnectivity)
        return base.environment(session.phoneConnectivity)
        #else
        return base
        #endif
    }
}
