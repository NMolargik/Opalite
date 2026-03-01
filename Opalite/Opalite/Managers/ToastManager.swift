//
//  ToastManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import SwiftUI

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
        toastContent
            .padding(.horizontal, 16)
            .frame(maxWidth: 300)
    }

    @ViewBuilder
    private var toastContent: some View {
        #if os(visionOS)
        toastBody
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(toast.style.backgroundColor.gradient)
                    .shadow(color: toast.style.backgroundColor.opacity(0.3), radius: 8, y: 4)
            )
        #else
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            toastBody
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular.tint(toast.style.backgroundColor).interactive())
        } else {
            toastBody
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(toast.style.backgroundColor.gradient)
                        .shadow(color: toast.style.backgroundColor.opacity(0.3), radius: 8, y: 4)
                )
        }
        #endif
    }

    private var toastBody: some View {
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
                HapticsManager.shared.impact()
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
                    .id(toastManager.currentToast?.message)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
                    HapticsManager.shared.impact()
                    toastManager.show(error: .colorCreationFailed)
                }

                Button("Show Success") {
                    HapticsManager.shared.impact()
                    toastManager.showSuccess("Color saved successfully")
                }

                Button("Show Info") {
                    HapticsManager.shared.impact()
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
