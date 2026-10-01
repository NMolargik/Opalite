//
//  Toast.swift
//  OpaliteDesignSystem
//
//  Lightweight top-of-screen toasts: style, item, manager, rendering, and the
//  `.toastContainer()` overlay. Error toasts can carry an action (e.g. "Get Onyx").
//

import SwiftUI
import OpaliteCore

// MARK: - Style

public enum ToastStyle: Sendable, Equatable {
    case error
    case success
    case info

    public var tint: Color {
        switch self {
        case .error: .red
        case .success: .green
        case .info: .opalitePurple
        }
    }

    public var systemImage: String {
        switch self {
        case .error: "exclamationmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }
}

// MARK: - Item

public struct ToastItem: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let style: ToastStyle
    public let systemImage: String?
    public let duration: TimeInterval
    public let actionTitle: String?
    public let action: (@MainActor () -> Void)?

    public init(message: String, style: ToastStyle = .info, systemImage: String? = nil, duration: TimeInterval = 3.0, actionTitle: String? = nil, action: (@MainActor () -> Void)? = nil) {
        self.message = message
        self.style = style
        self.systemImage = systemImage
        self.duration = action == nil ? duration : max(duration, 5)
        self.actionTitle = actionTitle
        self.action = action
    }

    public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Manager

@MainActor
@Observable
public final class ToastManager {
    public private(set) var currentToast: ToastItem?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    public init() {}

    public func show(_ toast: ToastItem) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = toast
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(toast.duration))
            if !Task.isCancelled { self?.dismiss() }
        }
    }

    public func show(message: String, style: ToastStyle = .info, systemImage: String? = nil) {
        show(ToastItem(message: message, style: style, systemImage: systemImage))
    }

    public func showSuccess(_ message: String, systemImage: String? = nil) {
        show(ToastItem(message: message, style: .success, systemImage: systemImage))
        Haptics.success()
    }

    /// Shows an error; `OpaliteError`s that need Onyx get an optional action.
    public func show(error: any Error, actionTitle: String? = nil, action: (@MainActor () -> Void)? = nil) {
        let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        let image = (error as? OpaliteError)?.systemImage
        show(ToastItem(message: message, style: .error, systemImage: image, actionTitle: actionTitle, action: action))
        Haptics.error()
    }

    public func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = nil
        }
    }
}

#if !os(watchOS)

// MARK: - View

public struct ToastView: View {
    let toast: ToastItem
    let onDismiss: () -> Void

    public init(toast: ToastItem, onDismiss: @escaping () -> Void) {
        self.toast = toast
        self.onDismiss = onDismiss
    }

    public var body: some View {
        toastBody
            .padding(.horizontal, Brand.Space.lg)
            .padding(.vertical, Brand.Space.md)
            .adaptiveGlassCapsule(tint: toast.style.tint)
            .padding(.horizontal, Brand.Space.lg)
            .frame(maxWidth: 420)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
    }

    private var toastBody: some View {
        HStack(spacing: Brand.Space.md) {
            Image(systemName: toast.systemImage ?? toast.style.systemImage)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(toast.style.tint)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            if let title = toast.actionTitle, let action = toast.action {
                Button(title) {
                    Haptics.selection()
                    action()
                    onDismiss()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .tint(toast.style.tint)
            }

            Button {
                Haptics.lightImpact()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Circle().fill(.quaternary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
    }
}

// MARK: - Container

public struct ToastContainerModifier: ViewModifier {
    @Environment(ToastManager.self) private var toastManager

    public init() {}

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast) { toastManager.dismiss() }
                        .id(toast.id)
                        .padding(.top, Brand.Space.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                }
            }
    }
}

extension View {
    /// Hosts toasts over this view. Needs a `ToastManager` in the environment.
    public func toastContainer() -> some View {
        modifier(ToastContainerModifier())
    }
}

#if DEBUG
#Preview("Toast Styles") {
    struct PreviewContainer: View {
        @State private var toastManager = ToastManager()

        var body: some View {
            VStack(spacing: 20) {
                Button("Show Success") { toastManager.showSuccess("Color saved") }
                Button("Show Info") { toastManager.show(message: "Syncing with iCloud…", style: .info, systemImage: "icloud.fill") }
                Button("Show Error") { toastManager.show(error: OpaliteError.paletteLimitReached, actionTitle: "Get Onyx") {} }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toastContainer()
            .environment(toastManager)
        }
    }
    return PreviewContainer()
}
#endif
#endif
