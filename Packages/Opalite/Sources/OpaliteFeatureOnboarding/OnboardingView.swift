//
//  OnboardingView.swift
//  OpaliteFeatureOnboarding
//
//  The paged introduction after the splash: one page per `OnboardingStep`, slid
//  horizontally, with Back, Continue, and a Skip on every page (per the HIG every page
//  is skippable). The profile page's display name is saved through `PortfolioModel`
//  when the flow finishes, whether by Done or by Skip.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import os
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

// MARK: - OnboardingView

public struct OnboardingView: View {
    private let onFinished: () -> Void

    @Environment(PortfolioModel.self) private var portfolio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var model = OnboardingViewModel()
    @State private var isConfigured = false

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                pages
                bottomBar
            }
        }
        .accessibilityIdentifier("onboardingView")
        .onAppear(perform: configure)
        .onChange(of: model.step) { _, _ in
            Haptics.selection()
            AccessibilityNotification.Announcement(model.pageAnnouncement).post()
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            groupedBackground
            LinearGradient.opaliteWash.opacity(0.6)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Label("Back", systemImage: "chevron.backward")
                    .labelStyle(.titleAndIcon)
            }
            .glassActionButton(prominent: false)
            .keyboardShortcut("[", modifiers: .command)
            .opacity(model.canGoBack ? 1 : 0)
            .disabled(!model.canGoBack)
            .accessibilityHidden(!model.canGoBack)
            .accessibilityHint("Goes to the previous page")
            .accessibilityIdentifier("backButton")

            Spacer()

            pageIndicator

            Spacer()

            Button("Skip") {
                skip()
            }
            .glassActionButton(prominent: false)
            .accessibilityHint("Skips the introduction")
            .accessibilityIdentifier("skipButton")
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.top, Brand.Space.sm)
        .padding(.bottom, Brand.Space.xs)
        .frame(maxWidth: horizontalSizeClass == .regular ? Brand.detailMaxWidth : .infinity)
        .frame(maxWidth: .infinity)
    }

    private var pageIndicator: some View {
        HStack(spacing: Brand.Space.xs + 2) {
            ForEach(OnboardingStep.allCases) { step in
                Capsule(style: .continuous)
                    .fill(step == model.step ? AnyShapeStyle(LinearGradient.opaliteHorizontal) : AnyShapeStyle(.tertiary))
                    .frame(width: step == model.step ? 24 : 8, height: 8)
                    .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: model.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(model.pageNumber) of \(model.pageCount)")
        .accessibilityValue(model.page.title)
    }

    // MARK: Pages

    private var pages: some View {
        ZStack {
            Group {
                if model.page.isForm {
                    OnboardingProfilePage(model: model, onSubmit: advance)
                } else {
                    OnboardingPageView(page: model.page)
                }
            }
            .id(model.step)
            .transition(pageTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .simultaneousGesture(swipeGesture)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let forward = model.direction == .forward
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var pageAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width < -80 {
                    guard !model.isLastStep else { return }
                    advance()
                } else if value.translation.width > 80 {
                    goBack()
                }
            }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: Brand.Space.sm) {
                Text(model.continueTitle)
                if !model.isLastStep {
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .primaryActionButton()
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("continueButton")
        .accessibilityHint(model.isLastStep ? "Finishes the introduction" : "Goes to the next page")
        .padding(.horizontal, Brand.Space.xl)
        .padding(.top, Brand.Space.md)
        .padding(.bottom, Brand.Space.lg)
    }

    // MARK: Actions

    private func configure() {
        guard !isConfigured else { return }
        isConfigured = true
        model.displayName = OnboardingViewModel.initialDisplayName(from: portfolio.authorName)
        model.onFinished = { name in
            portfolio.setAuthorName(name)
            Haptics.success()
            Log.app.info("Onboarding finished")
            onFinished()
        }
    }

    private func advance() {
        if model.isLastStep {
            model.finish()
        } else {
            slide(.forward) { model.next() }
        }
    }

    private func goBack() {
        guard model.canGoBack else { return }
        slide(.backward) { model.previous() }
    }

    private func skip() {
        Haptics.lightImpact()
        model.skip()
    }

    /// Commits the direction before the step changes so the outgoing page slides the
    /// right way, then animates the page change on the next run-loop turn.
    private func slide(_ direction: OnboardingViewModel.Direction, _ change: @escaping () -> Void) {
        model.direction = direction
        Task { @MainActor in
            withAnimation(pageAnimation) { change() }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Onboarding") {
    OnboardingView(onFinished: {})
        .previewEnvironment()
}

#Preview("Onboarding · no Onyx") {
    OnboardingView(onFinished: {})
        .previewEnvironment(hasOnyx: false)
}
#endif
#endif
