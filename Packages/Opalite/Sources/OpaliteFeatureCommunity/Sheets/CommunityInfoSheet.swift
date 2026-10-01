//
//  CommunityInfoSheet.swift
//  OpaliteFeatureCommunity
//
//  What the Community is and how to take part: saving, publishing, discovering creators,
//  and the house rules (reporting, auto-hiding, and the publish rate limit).
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

public struct CommunityInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.xl) {
                    header

                    VStack(spacing: Brand.Space.md) {
                        CommunityInfoCard(
                            systemImage: "square.and.arrow.down.fill",
                            tint: .blue,
                            title: String(localized: "Save to Your Portfolio"),
                            description: String(localized: "Found a color or palette you love? Save it to your Portfolio with one tap. Saving requires Onyx.")
                        )
                        CommunityInfoCard(
                            systemImage: "square.and.arrow.up.fill",
                            tint: .green,
                            title: String(localized: "Share Your Creations"),
                            description: String(localized: "Open any color or palette in your Portfolio, choose Share, then Publish to Community. Your display name goes with it.")
                        )
                        CommunityInfoCard(
                            systemImage: "person.2.fill",
                            tint: .purple,
                            title: String(localized: "Discover Creators"),
                            description: String(localized: "Tap a publisher's name to see everything they've shared.")
                        )
                        CommunityInfoCard(
                            systemImage: "flag.fill",
                            tint: .orange,
                            title: String(localized: "Keep It Kind"),
                            description: String(localized: "Report anything inappropriate. Content with \(CommunityModeration.autoHideThreshold) reports is hidden automatically, and publishing is limited to \(PublishRateLimiter.maxPublishesPerHour) items an hour.")
                        )
                    }
                    .frame(maxWidth: Brand.readableWidth)
                }
                .padding(.horizontal, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xxl)
                .frame(maxWidth: .infinity)
            }
            .background(groupedBackground)
            .softScrollEdgesIfAvailable()
            .navigationTitle("About the Community")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityIdentifier("community.info.done")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: Brand.Space.md) {
            Image(systemName: "person.2.fill")
                .font(.system(.largeTitle, weight: .semibold))
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient.opaliteHorizontal)
                .padding(Brand.Space.lg)
                .background(Circle().fill(.ultraThinMaterial))
                .accessibilityHidden(true)

            Text("Colors, shared.")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("A space to discover and share colors and palettes with creators everywhere.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Brand.readableWidth)
        }
        .padding(.top, Brand.Space.lg)
        .accessibilityElement(children: .combine)
    }
}

private struct CommunityInfoCard: View {
    let systemImage: String
    let tint: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint.gradient)
                .frame(width: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Brand.Space.lg)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Info") {
    CommunityInfoSheet()
}
#endif
#endif
