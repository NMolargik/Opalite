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
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false
    
    @State private var appStage: AppStage = .splash
    
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
            case .main:
                MainView()
                .environment(colorManager)
                .environment(canvasManager)
                .id("main")
                .transition(leadingTransition)
                .zIndex(0)
            }
        }
        .task {
            await prepareApp()
        }
        .onAppear {
            colorManager.isMainWindowOpen = true
        }
        .onDisappear {
            colorManager.isMainWindowOpen = false
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
}
