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
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false
    @State private var viewModel: ContentView.ViewModel = ViewModel()
    
    var body: some View {
        ZStack {
            switch viewModel.appStage {
            case .splash:
                SplashView(
                    onContinue: {
                        withAnimation {
                            viewModel.appStage = .onboarding
                        }
                    }
                )
                    .id("splash")
                    .transition(viewModel.leadingTransition)
                    .zIndex(1)
            case .onboarding:
                OnboardingView(
                    onContinue: {
                        withAnimation {
                            viewModel.appStage = .main
                        }
                    }
                )
                    .environment(colorManager)
                    .id("onboarding")
                    .transition(viewModel.leadingTransition)
                    .zIndex(1)
            case .main:
                MainView()
                    .environment(colorManager)
                    .id("main")
                    .transition(viewModel.leadingTransition)
                    .zIndex(0)
            }
        }
        .task {
            await prepareApp()
        }
    }
    
    private func prepareApp() async {
        await colorManager.refresh()
        viewModel.appStage = isOnboardingComplete ? .main : .splash
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: OpaliteColor.self, OpalitePalette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let colorManager = ColorManager(context: container.mainContext)
    return ContentView()
        .modelContainer(container)
        .environment(colorManager)
}
