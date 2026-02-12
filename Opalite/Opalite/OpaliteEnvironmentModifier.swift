//
//  OpaliteEnvironmentModifier.swift
//  Opalite
//
//  Injects all shared managers into the environment.
//  Used by both the main WindowGroup and SwatchBar scenes.
//

import SwiftUI
import SwiftData

struct OpaliteEnvironmentModifier: ViewModifier {
    let modelContainer: ModelContainer
    let colorManager: ColorManager
    let canvasManager: CanvasManager
    let communityManager: CommunityManager
    let toastManager: ToastManager
    let subscriptionManager: SubscriptionManager
    let quickActionManager: QuickActionManager
    let hexCopyManager: HexCopyManager
    let reviewRequestManager: ReviewRequestManager
    let importCoordinator: ImportCoordinator
    let immersiveColorManager: ImmersiveColorManager

    func body(content: Content) -> some View {
        content
            .modelContainer(modelContainer)
            .environment(colorManager)
            .environment(canvasManager)
            .environment(communityManager)
            .environment(toastManager)
            .environment(subscriptionManager)
            .environment(quickActionManager)
            .environment(hexCopyManager)
            .environment(reviewRequestManager)
            .environment(importCoordinator)
            .environment(immersiveColorManager)
    }
}

extension Scene {
    func opaliteEnvironment(
        modelContainer: ModelContainer,
        colorManager: ColorManager,
        canvasManager: CanvasManager,
        communityManager: CommunityManager,
        toastManager: ToastManager,
        subscriptionManager: SubscriptionManager,
        quickActionManager: QuickActionManager,
        hexCopyManager: HexCopyManager,
        reviewRequestManager: ReviewRequestManager,
        importCoordinator: ImportCoordinator,
        immersiveColorManager: ImmersiveColorManager
    ) -> some Scene {
        self
            .modelContainer(modelContainer)
            .environment(colorManager)
            .environment(canvasManager)
            .environment(communityManager)
            .environment(toastManager)
            .environment(subscriptionManager)
            .environment(quickActionManager)
            .environment(hexCopyManager)
            .environment(reviewRequestManager)
            .environment(importCoordinator)
            .environment(immersiveColorManager)
    }
}
