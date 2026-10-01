//
//  CommunityNamePromptSheet.swift
//  OpaliteFeatureCommunity
//
//  The one-time prompt on the first Community visit: pick the display name shown on
//  published colors and palettes. Saving writes the profile name (Portfolio) and the
//  Community's publisher name; skipping keeps the current one.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct CommunityNamePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(CommunityModel.self) private var community

    @State private var draft = CommunityNameDraft(storedName: "")
    @FocusState private var isNameFieldFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.xl) {
                    VStack(spacing: Brand.Space.md) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(.largeTitle, weight: .semibold))
                            .imageScale(.large)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(LinearGradient.opaliteHorizontal)
                            .padding(Brand.Space.lg)
                            .background(Circle().fill(.ultraThinMaterial))
                            .accessibilityHidden(true)

                        Text("Choose Your Display Name")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text("This name appears on colors and palettes you publish to the Community. You can change it any time in Settings.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Brand.Space.lg)

                    VStack(alignment: .leading, spacing: Brand.Space.sm) {
                        Text("Display Name")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        TextField("Your name", text: $draft.text)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .textContentType(.name)
                            .submitLabel(.done)
                            .focused($isNameFieldFocused)
                            .onSubmit(save)
                            .padding(Brand.Space.md)
                            .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
                            .accessibilityLabel(Text("Display name"))
                            .accessibilityIdentifier("community.nameField")

                        Text("\(draft.trimmed.count) of \(CommunityNameDraft.maxLength)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .contentTransition(.numericText())
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: Brand.readableWidth)
                .padding(.horizontal, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xxl)
                .frame(maxWidth: .infinity)
            }
            .background(groupedBackground)
            .softScrollEdgesIfAvailable()
            .navigationTitle("Welcome")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityIdentifier("community.namePrompt.skip")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.canSave)
                        .accessibilityIdentifier("community.namePrompt.save")
                }
            }
            .onAppear {
                draft = CommunityNameDraft(storedName: portfolio.authorName)
                isNameFieldFocused = true
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard draft.canSave else { return }
        Haptics.success()
        portfolio.setAuthorName(draft.trimmed)
        community.publisherName = portfolio.authorName
        dismiss()
    }
}

#if DEBUG
#Preview("Name prompt") {
    CommunityNamePromptSheet()
        .previewEnvironment()
}
#endif
#endif
