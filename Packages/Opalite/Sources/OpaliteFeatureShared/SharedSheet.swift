//
//  SharedSheet.swift
//  OpaliteFeatureShared
//
//  `.sheet` that carries the shared models into the presented content. On Mac Catalyst
//  SwiftUI evaluates a sheet's root view (for its presentation preferences) before the
//  presenter's environment reaches it, so a root that reads a required Observable —
//  `@Environment(PortfolioModel.self)` and friends — traps with "No Observable object
//  found". The models are read here, in the presenter, and re-applied inside the content,
//  which makes them part of the presented tree where that early pass can see them.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices

extension View {
    /// `.sheet(isPresented:)` whose content inherits every shared model (see the file note).
    public func sharedSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ContentBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(SharedSheetModifier(isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
    }

    /// `.sheet(item:)` whose content inherits every shared model (see the file note).
    public func sharedSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ContentBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(SharedItemSheetModifier(item: item, onDismiss: onDismiss, sheetContent: content))
    }
}

/// The shared models, read where this property lives — the *presenter* — so the values
/// come from a working environment and can be re-applied inside presented content.
private struct SharedModels: DynamicProperty {
    @Environment(AppRouter.self) var router: AppRouter?
    @Environment(ToastManager.self) var toasts: ToastManager?
    @Environment(PortfolioModel.self) var portfolio: PortfolioModel?
    @Environment(CanvasModel.self) var canvases: CanvasModel?
    @Environment(CommunityModel.self) var community: CommunityModel?
    @Environment(HexCopyModel.self) var hexCopy: HexCopyModel?
    @Environment(ImportModel.self) var importer: ImportModel?
    @Environment(CloudSyncManager.self) var cloudSync: CloudSyncManager?
    @Environment(SubscriptionManager.self) var subscriptions: SubscriptionManager?
    @Environment(ColorNameSuggestionService.self) var colorNaming: ColorNameSuggestionService?
    #if os(iOS) && canImport(WatchConnectivity)
    @Environment(PhoneConnectivityManager.self) var phoneConnectivity: PhoneConnectivityManager?
    #endif
    @Environment(\.onyxEntitlement) var entitlement

    /// Re-applies every captured model to `content`.
    func apply<V: View>(to content: V) -> some View {
        let base = content
            .environment(router)
            .environment(toasts)
            .environment(portfolio)
            .environment(canvases)
            .environment(community)
            .environment(hexCopy)
            .environment(importer)
            .environment(cloudSync)
            .environment(subscriptions)
            .environment(colorNaming)
            .environment(\.onyxEntitlement, entitlement)
        #if os(iOS) && canImport(WatchConnectivity)
        return base.environment(phoneConnectivity)
        #else
        return base
        #endif
    }
}

private struct SharedSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let sheetContent: () -> SheetContent
    private var models = SharedModels()

    init(isPresented: Binding<Bool>, onDismiss: (() -> Void)?, sheetContent: @escaping () -> SheetContent) {
        _isPresented = isPresented
        self.onDismiss = onDismiss
        self.sheetContent = sheetContent
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            models.apply(to: sheetContent())
        }
    }
}

private struct SharedItemSheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    let sheetContent: (Item) -> SheetContent
    private var models = SharedModels()

    init(item: Binding<Item?>, onDismiss: (() -> Void)?, sheetContent: @escaping (Item) -> SheetContent) {
        _item = item
        self.onDismiss = onDismiss
        self.sheetContent = sheetContent
    }

    func body(content: Content) -> some View {
        content.sheet(item: $item, onDismiss: onDismiss) { item in
            models.apply(to: sheetContent(item))
        }
    }
}
#endif
