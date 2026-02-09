//
//  CommunityInfoSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

struct CommunityInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero icon
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                        .padding(.top, 20)

                    // Title and description
                    VStack(spacing: 12) {
                        Text("Welcome to the Community")
                            .font(.title.bold())

                        Text("A community-driven space to discover and share colors and palettes with creators around the world.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Feature cards
                    VStack(spacing: 16) {
                        CommunityInfoCard(
                            icon: "arrow.down.circle.fill",
                            iconColor: .teal,
                            title: "Save to Your Portfolio",
                            description: "Found a color or palette you love? Save it directly to your portfolio with a single tap."
                        )

                        CommunityInfoCard(
                            icon: "arrow.up.circle.fill",
                            iconColor: .green,
                            title: "Share Your Creations",
                            description: "Publish your own colors and palettes to share with the community."
                        )

                        CommunityInfoCard(
                            icon: "square.and.arrow.up",
                            iconColor: .orange,
                            title: "How to Publish",
                            description: "Open any color or palette in your portfolio, tap the share menu, and select \"Publish to Community\"."
                        )

                        CommunityInfoCard(
                            icon: "person.2.fill",
                            iconColor: .purple,
                            title: "Discover Creators",
                            description: "View publisher profiles to see more of their work and find new inspiration."
                        )
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Info Card

private struct CommunityInfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CommunityInfoSheet()
}
