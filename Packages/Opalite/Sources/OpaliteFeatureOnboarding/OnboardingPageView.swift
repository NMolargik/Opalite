//
//  OnboardingPageView.swift
//  OpaliteFeatureOnboarding
//
//  The two page bodies: a feature page (hero symbol, title, three feature rows) and the
//  profile form (display name). Both are centered at the readable width and scroll when
//  Dynamic Type or a short window demands it.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

// MARK: - Feature page

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.xl) {
                OnboardingPageHeader(page: page)

                VStack(spacing: 0) {
                    ForEach(Array(page.features.enumerated()), id: \.element.id) { index, feature in
                        OnboardingFeatureRow(feature: feature)
                        if index < page.features.count - 1 {
                            Divider().padding(.leading, Brand.Space.lg)
                        }
                    }
                }
                .cardSurface()
            }
            .padding(.horizontal, Brand.Space.xl)
            .padding(.vertical, Brand.Space.xl)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .softScrollEdgesIfAvailable()
    }
}

// MARK: - Header

/// Hero symbol in the brand purple, then the title and subtitle.
struct OnboardingPageHeader: View {
    let page: OnboardingPage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var symbolBox: CGFloat = 120

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            Image(systemName: page.systemImage)
                .font(.system(size: symbolSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.opalitePurpleInk)
                .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
                .frame(height: symbolBox)
                .accessibilityHidden(true)

            VStack(spacing: Brand.Space.sm) {
                Text(page.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            bounce.toggle()
        }
    }
}

// MARK: - Feature row

/// A `DetailRow`-style line: a tinted glyph, a title with a one-line detail, and the
/// Onyx badge on gated features. One accessibility element.
struct OnboardingFeatureRow: View {
    let feature: OnboardingFeature

    @ScaledMetric(relativeTo: .body) private var glyphBox: CGFloat = 36

    var body: some View {
        HStack(alignment: .center, spacing: Brand.Space.md) {
            Image(systemName: feature.systemImage)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.opalitePurpleInk)
                .frame(width: glyphBox, height: glyphBox)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                        .fill(Color.opalitePurpleInk.opacity(0.12))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.body.weight(.semibold))
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Brand.Space.sm)

            if feature.requiresOnyx {
                OnyxBadge()
            }
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.md)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Profile page

/// The one page that collects input: a grouped form with the display-name field.
struct OnboardingProfilePage: View {
    @Bindable var model: OnboardingViewModel
    var onSubmit: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        Form {
            Section {
                OnboardingPageHeader(page: model.page)
                    .padding(.top, Brand.Space.lg)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                TextField("Display Name", text: $model.displayName, prompt: Text("Your name"))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit(onSubmit)
                    .accessibilityIdentifier("displayNameField")
            } header: {
                Text("Display Name")
            } footer: {
                Text("Shown on colors and palettes you publish to the Community. Leave it blank to stay anonymous.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .dismissingKeyboardOnScroll()
        .frame(maxWidth: Brand.readableWidth)
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    /// Interactive keyboard dismissal where a software keyboard scrolls with content.
    @ContentBuilder
    func dismissingKeyboardOnScroll() -> some View {
        #if os(iOS)
        scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Feature page") {
    OnboardingPageView(page: .page(for: .portfolio))
        .background(groupedBackground)
}

#Preview("Profile page") {
    OnboardingProfilePage(model: OnboardingViewModel(step: .profile, displayName: "Nick"), onSubmit: {})
        .background(groupedBackground)
}
#endif
#endif
