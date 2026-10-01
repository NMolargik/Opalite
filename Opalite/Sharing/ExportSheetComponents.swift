//
//  ExportSheetComponents.swift
//  Opalite
//
//  Created by Nick Molargik on 2/8/26.
//

import SwiftUI

// MARK: - Publish to Community Button

struct PublishToCommunityButton: View {
    let isOffline: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticsManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOffline ? "wifi.slash" : "person.2")
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(isOffline ? Color.secondary : Color.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Publish to Community")
                        .font(.headline)
                        .foregroundStyle(isOffline ? Color.secondary : Color.primary)

                    Text(isOffline ? "Requires internet connection" : "Share with the Opalite community")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isOffline)
    }
}

// MARK: - Save to File Button

struct SaveToFileButton: View {
    var description: String = "Save as a native Opalite file."
    let isExporting: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticsManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Save to File")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
    }
}

// MARK: - Export Format Button

struct ExportFormatButton<F: ExportFormat & Equatable>: View {
    let format: F
    let hasOnyx: Bool
    let isExporting: Bool
    let selectedFormat: F?
    let action: () -> Void

    private var requiresOnyx: Bool {
        !format.isFreeFormat && !hasOnyx
    }

    var body: some View {
        Button {
            HapticsManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: format.icon)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(format.iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(format.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if requiresOnyx {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(format.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isExporting && selectedFormat == format {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .accessibilityLabel(format.displayName)
        .accessibilityHint(requiresOnyx ? "Requires Onyx subscription" : format.description)
    }
}
