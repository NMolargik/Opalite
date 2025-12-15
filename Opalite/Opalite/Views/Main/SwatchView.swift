//
//  SwatchView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

import UniformTypeIdentifiers

struct SwatchView: View {
    private var fill: [OpaliteColor]
    private var width: CGFloat?
    private var height: CGFloat
    private var badgeText: String?
    @Binding var isEditingBadge: Bool?
    private var saveBadge: ((String) -> Void)?
    private var menu: AnyView?
    private var contextMenu: AnyView?
    
    @State private var editedBadgeText: String = ""
    @State private var isMenuPresented: Bool = false

    init(
        fill: [OpaliteColor],
        width: CGFloat? = nil,
        height: CGFloat,
        badgeText: String? = nil,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        menu: AnyView? = nil,
        contextMenu: AnyView? = nil
    ) {
        self.fill = fill
        self.width = width
        self.height = height
        self.badgeText = badgeText
        self._isEditingBadge = isEditingBadge
        self.saveBadge = saveBadge
        self.menu = menu
        self.contextMenu = contextMenu
    }

    init<MenuContent: View>(
        fill: [OpaliteColor],
        width: CGFloat? = nil,
        height: CGFloat,
        badgeText: String? = nil,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        @ViewBuilder menu: @escaping () -> MenuContent
    ) {
        self.init(
            fill: fill,
            width: width,
            height: height,
            badgeText: badgeText,
            isEditingBadge: isEditingBadge,
            saveBadge: saveBadge,
            menu: AnyView(menu())
        )
    }
    
    init<ContextMenuContent: View>(
        fill: [OpaliteColor],
        width: CGFloat? = nil,
        height: CGFloat,
        badgeText: String? = nil,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        @ViewBuilder contextMenu: @escaping () -> ContextMenuContent
    ) {
        self.init(
            fill: fill,
            width: width,
            height: height,
            badgeText: badgeText,
            isEditingBadge: isEditingBadge,
            saveBadge: saveBadge,
            menu: nil,
            contextMenu: AnyView(contextMenu())
        )
    }
    
    // MARK: - The View
    var body: some View {
        return RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: fill.map { $0.swiftUIColor }),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .if(!fill.isEmpty) { view in
                view.onDrag {
                    provideDragItem()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.thinMaterial, lineWidth: 5)
            )
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                badgeContent
                    .frame(maxWidth: 500, alignment: .leading)
            }
            .overlay(alignment: .bottomTrailing) {
                menuContent
            }
            .contextMenu {
                contextMenuContent
            }
    }
    
    // MARK: - Badge Content
    @ViewBuilder
    private var badgeContent: some View {
        if let badgeText {
            ZStack(alignment: .leading) {
                // Read-only label state
                if isEditingBadge != true {
                    Text(badgeText)
                        .foregroundStyle(fill.first?.idealTextColor() ?? .black)
                        .bold()

                }

                // Editing state
                if isEditingBadge == true {
                    HStack(spacing: 8) {
                        TextField("Badge", text: Binding(
                            get: { editedBadgeText.isEmpty ? badgeText : editedBadgeText },
                            set: { editedBadgeText = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .foregroundStyle(fill.first?.idealTextColor() ?? .black)
                        .bold()
                        .submitLabel(.done)
                        .onSubmit {
                            let finalText = editedBadgeText.isEmpty ? badgeText : editedBadgeText
                            saveBadge?(finalText)
                            editedBadgeText = ""
                            withAnimation(.easeInOut) {
                                isEditingBadge = false
                            }
                        }

                        Button {
                            let finalText = editedBadgeText.isEmpty ? badgeText : editedBadgeText
                            saveBadge?(finalText)
                            editedBadgeText = ""
                            withAnimation(.easeInOut) {
                                isEditingBadge = false
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.green)
                        }
                        .contentShape(Circle())
                        .hoverEffect(.lift)
                    }
                }
            }
            .frame(height: 20)
            .padding(8)
            .glassEffect(.clear)
            .padding(8)
            .mask(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentTransition(.interpolate)
            .animation(.bouncy, value: isEditingBadge)
        }
    }
    
    // MARK: - Menu Content
    @ViewBuilder
    private var menuContent: some View {
        if let menu {
            Menu {
                menu
            } label: {
                Image(systemName: "ellipsis")
                    .imageScale(.large)
                    .foregroundStyle(fill.first?.idealTextColor() ?? .black)
                    .frame(width: 8, height: 8)
                    .padding(12)
                    .background(
                        Circle().fill(.clear)
                    )
                    .glassEffect(.clear)
                    .contentShape(Circle())
                    .hoverEffect(.lift)
            }
            .menuStyle(.automatic)
            .padding(8)
        }
    }

    // MARK: - Context Menu Content
    @ViewBuilder
    private var contextMenuContent: some View {
        if let contextMenu {
            contextMenu
        } else {
            EmptyView()
        }
    }

    // MARK: - Drag Support
    private func provideDragItem() -> NSItemProvider {
        // If single color, provide a 512x512 square image of the rounded rectangle with that fill for cross-app drops
        if fill.count == 1 {
            if let imageData = renderSwatchImage(size: CGSize(width: 512, height: 512)) {
                let provider = NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.png.identifier)
                return provider
            }
        }
        // For multiple colors (or fallback), still provide an image of the current swatch appearance
        if let imageData = renderSwatchImage(size: CGSize(width: 512, height: 512)) {
            let provider = NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.png.identifier)
            return provider
        }
        return NSItemProvider()
    }

    private func renderSwatchImage(size: CGSize) -> Data? {
        let view = Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: fill.map { $0.swiftUIColor }),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width, height: size.height)

        #if canImport(UIKit)
        // Prefer SwiftUI's ImageRenderer when available. This avoids UIKit hosting / safe-area / backing-store quirks
        // that can cause transparent strips or fully-empty renders on iPad.
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(size)
            // Prefer trait-based scale instead of UIScreen.main (deprecated in iOS 26)
            // Use a temporary hosting controller to obtain a traitCollection in context
            let hc = UIHostingController(rootView: view)
            hc.view.frame = CGRect(origin: .zero, size: size)
            hc.view.bounds = CGRect(origin: .zero, size: size)
            let traitScale = hc.traitCollection.displayScale
            renderer.scale = CGFloat(traitScale)

            renderer.isOpaque = false

            if let uiImage = renderer.uiImage {
                return uiImage.pngData()
            }
        }

        // Fallback for iOS 15 and earlier: host in a UIHostingController and drawHierarchy.
        // (Layer rendering can be blank for some SwiftUI content when offscreen.)
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        // Prefer trait-based scale; avoid UIScreen.main
        let hc = UIHostingController(rootView: view)
        let traitScale = hc.traitCollection.displayScale
        format.scale = CGFloat(traitScale)
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        return image.pngData()
        #elseif canImport(AppKit)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        // Ensure layout is up to date
        hostingView.layoutSubtreeIfNeeded()

        // Use AppKit's caching APIs to avoid coordinate-system / flipping issues that can
        // produce a transparent strip when drawing via a raw CG context.
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }

        // Match screen scale to avoid subtle rendering artifacts
        rep.size = hostingView.bounds.size

        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview("With Menu") {
    StatefulPreview()
}

private struct StatefulPreview: View {
    @State private var isEditing: Bool? = true

    var body: some View {
        let sampleColors: [OpaliteColor] = [OpaliteColor.sample, OpaliteColor.sample2]

        VStack {
            Toggle("Editing Badge", isOn: Binding(
                get: { isEditing ?? false },
                set: { isEditing = $0 }
            ))
            .padding(.bottom)

            HStack(alignment: .bottom) {
                SwatchView(
                    fill: [sampleColors.first!],
                    width: 250,
                    height: 250,
                    badgeText: "Sample Color",
                    isEditingBadge: .constant(nil),
                    menu: {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )

                SwatchView(
                    fill: [OpaliteColor(red: 0, green: 0, blue: 0)],
                    width: 250,
                    height: 250,
                    badgeText: "Sample Color",
                    isEditingBadge: $isEditing,
                    menu: {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )

                SwatchView(
                    fill: [OpaliteColor(red: 255, green: 255, blue: 255)],
                    width: 250,
                    height: 250,
                    badgeText: "Sample Color",
                    isEditingBadge: .constant(nil),
                    menu: {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )

                SwatchView(
                    fill: [OpaliteColor(red: 1, green: 1.0, blue: 0.5)],
                      width: 75,
                      height: 75
                  )
            }

            SwatchView(
                fill: sampleColors,
                height: 350,
                badgeText: "Sample Color",
                isEditingBadge: $isEditing
            )
        }
        .padding()
    }
}

