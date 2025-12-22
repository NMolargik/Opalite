//
//  ToastManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import SwiftUI

// MARK: - Opalite Error Types

/// Unified error type for all Opalite operations
enum OpaliteError: LocalizedError, Equatable {
    // MARK: - Color Operations
    case colorCreationFailed
    case colorUpdateFailed
    case colorDeletionFailed
    case colorFetchFailed

    // MARK: - Palette Operations
    case paletteCreationFailed
    case paletteUpdateFailed
    case paletteDeletionFailed
    case paletteFetchFailed

    // MARK: - Canvas Operations
    case canvasCreationFailed
    case canvasUpdateFailed
    case canvasDeletionFailed
    case canvasFetchFailed
    case canvasSaveFailed

    // MARK: - Relationship Operations
    case colorAttachFailed
    case colorDetachFailed

    // MARK: - Import/Export Operations
    case importFailed(reason: String)
    case exportFailed(reason: String)
    case pdfExportFailed

    // MARK: - Data Operations
    case saveFailed
    case loadFailed
    case sampleDataFailed

    // MARK: - Generic
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        // Color
        case .colorCreationFailed:
            return "Unable to create color"
        case .colorUpdateFailed:
            return "Unable to update color"
        case .colorDeletionFailed:
            return "Unable to delete color"
        case .colorFetchFailed:
            return "Unable to load colors"

        // Palette
        case .paletteCreationFailed:
            return "Unable to create palette"
        case .paletteUpdateFailed:
            return "Unable to update palette"
        case .paletteDeletionFailed:
            return "Unable to delete palette"
        case .paletteFetchFailed:
            return "Unable to load palettes"

        // Canvas
        case .canvasCreationFailed:
            return "Unable to create canvas"
        case .canvasUpdateFailed:
            return "Unable to update canvas"
        case .canvasDeletionFailed:
            return "Unable to delete canvas"
        case .canvasFetchFailed:
            return "Unable to load canvases"
        case .canvasSaveFailed:
            return "Unable to save canvas"

        // Relationships
        case .colorAttachFailed:
            return "Unable to add color to palette"
        case .colorDetachFailed:
            return "Unable to remove color from palette"

        // Import/Export
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .pdfExportFailed:
            return "Unable to export PDF"

        // Data
        case .saveFailed:
            return "Unable to save changes"
        case .loadFailed:
            return "Unable to load data"
        case .sampleDataFailed:
            return "Unable to load sample data"

        // Generic
        case .unknownError(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .colorCreationFailed, .paletteCreationFailed, .canvasCreationFailed:
            return "plus.circle.fill"
        case .colorUpdateFailed, .paletteUpdateFailed, .canvasUpdateFailed:
            return "pencil.circle.fill"
        case .colorDeletionFailed, .paletteDeletionFailed, .canvasDeletionFailed:
            return "trash.circle.fill"
        case .colorFetchFailed, .paletteFetchFailed, .canvasFetchFailed, .loadFailed:
            return "arrow.down.circle.fill"
        case .canvasSaveFailed, .saveFailed:
            return "externaldrive.fill.badge.xmark"
        case .colorAttachFailed, .colorDetachFailed:
            return "link.circle.fill"
        case .importFailed:
            return "square.and.arrow.down.fill"
        case .exportFailed, .pdfExportFailed:
            return "square.and.arrow.up.fill"
        case .sampleDataFailed:
            return "doc.fill.badge.plus"
        case .unknownError:
            return "exclamationmark.triangle.fill"
        }
    }

    static func == (lhs: OpaliteError, rhs: OpaliteError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

// MARK: - Toast Style

enum ToastStyle {
    case error
    case success
    case info

    var backgroundColor: Color {
        switch self {
        case .error:
            return .red
        case .success:
            return .green
        case .info:
            return .blue
        }
    }

    var iconName: String {
        switch self {
        case .error:
            return "xmark.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

// MARK: - Toast Item

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
    let icon: String?
    let duration: TimeInterval

    init(message: String, style: ToastStyle = .info, icon: String? = nil, duration: TimeInterval = 3.0) {
        self.message = message
        self.style = style
        self.icon = icon
        self.duration = duration
    }

    init(error: OpaliteError, duration: TimeInterval = 3.0) {
        self.message = error.errorDescription ?? "An error occurred"
        self.style = .error
        self.icon = error.systemImage
        self.duration = duration
    }

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager

@MainActor
@Observable
final class ToastManager {
    private(set) var currentToast: ToastItem?
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: ToastItem) {
        dismissTask?.cancel()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = toast
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(toast.duration))
            if !Task.isCancelled {
                dismiss()
            }
        }
    }

    func show(error: OpaliteError) {
        show(ToastItem(error: error))
    }

    func show(message: String, style: ToastStyle = .info, icon: String? = nil) {
        show(ToastItem(message: message, style: style, icon: icon))
    }

    func showSuccess(_ message: String) {
        show(ToastItem(message: message, style: .success))
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = nil
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon ?? toast.style.iconName)
                .font(.title3)
                .fontWeight(.semibold)

            Text(toast.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(6)
                    .background(Circle().fill(.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(toast.style.backgroundColor.gradient)
                .shadow(color: toast.style.backgroundColor.opacity(0.3), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Toast Container Modifier

struct ToastContainerModifier: ViewModifier {
    @Environment(ToastManager.self) private var toastManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast) {
                        toastManager.dismiss()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .zIndex(999)
                }
            }
    }
}

extension View {
    func toastContainer() -> some View {
        modifier(ToastContainerModifier())
    }
}

#Preview("Toast Styles") {
    struct PreviewContainer: View {
        @State private var toastManager = ToastManager()

        var body: some View {
            VStack(spacing: 20) {
                Button("Show Error") {
                    toastManager.show(error: .colorCreationFailed)
                }

                Button("Show Success") {
                    toastManager.showSuccess("Color saved successfully")
                }

                Button("Show Info") {
                    toastManager.show(message: "Tip: Drag colors to organize", style: .info)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toastContainer()
            .environment(toastManager)
        }
    }
    return PreviewContainer()
}
