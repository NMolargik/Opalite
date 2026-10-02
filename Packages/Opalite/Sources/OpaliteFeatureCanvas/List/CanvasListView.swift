//
//  CanvasListView.swift
//  OpaliteFeatureCanvas
//
//  The Canvas tab root: an adaptive grid of thumbnails with a prominent New Canvas action.
//  Opening goes through `CanvasModel.requestOpen` (the shell pushes `pendingCanvasID`, or
//  shows the paywall for canvases the free tier can't open).
//

import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct CanvasListView: View {
    public init() {}

    public var body: some View {
        #if os(iOS) || os(visionOS)
        CanvasGridView()
        #else
        EmptyView()
        #endif
    }
}

#if os(iOS) || os(visionOS)
private struct CanvasGridView: View {
    @Environment(CanvasModel.self) private var canvases
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onyxEntitlement) private var entitlement

    @State private var renaming: CanvasFile?
    @State private var deleting: CanvasFile?
    @State private var newCanvasBounce = false

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 280), spacing: Brand.Space.lg)]

    var body: some View {
        Group {
            if canvases.canvases.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .background(groupedBackground.ignoresSafeArea())
        .navigationTitle("Canvas")
        .navigationSubtitleIfAvailable(subtitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createCanvas()
                } label: {
                    Label("New Canvas", systemImage: "plus")
                        .symbolEffect(.bounce, value: newCanvasBounce)
                }
                .accessibilityIdentifier("canvas.new")
                .accessibilityHint(canvases.canCreateCanvas ? Text("Creates a new drawing canvas") : Text("Unlimited canvases require Onyx"))
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .canvasRenameAlert(for: $renaming)
        .canvasDeleteConfirmation(for: $deleting)
        .refreshable { canvases.refresh() }
    }

    private var subtitle: String {
        let count = canvases.canvases.count
        return count == 1 ? String(localized: "1 canvas") : String(localized: "\(count) canvases")
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Brand.Space.lg) {
                ForEach(canvases.canvases) { canvas in
                    let locked = !canvases.canAccess(canvas)
                    Button {
                        Haptics.lightImpact()
                        canvases.requestOpen(canvas)
                    } label: {
                        CanvasCard(canvas: canvas, isLocked: locked)
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                    .accessibilityIdentifier("canvas.card.\(canvas.id.uuidString)")
                    .contextMenu { contextMenu(for: canvas) }
                }
            }
            .padding(Brand.Space.lg)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .snappy, value: canvases.canvases.map(\.id))
        }
        .softScrollEdgesIfAvailable()
    }

    @ContentBuilder
    private func contextMenu(for canvas: CanvasFile) -> some View {
        Button {
            Haptics.selection()
            canvases.requestOpen(canvas)
        } label: {
            Label("Open", systemImage: "pencil.and.outline")
        }
        Button {
            Haptics.selection()
            renaming = canvas
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Menu {
            PaletteLinkMenuContent(canvas: canvas)
        } label: {
            Label("Link Palette", systemImage: "link")
        }
        Divider()
        Button(role: .destructive) {
            Haptics.selection()
            deleting = canvas
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .destructiveMenuItem()
    }

    // MARK: - Empty

    private var emptyState: some View {
        EmptyStateView("No Canvases", systemImage: "scribble.variable", description: String(localized: "Sketch with Apple Pencil, place shapes, and paint with your own swatches.")) {
            Button {
                createCanvas()
            } label: {
                Label("New Canvas", systemImage: "plus")
            }
            .primaryActionButton()
            if !entitlement.hasOnyx {
                Text("One canvas is free. Unlimited canvases come with Onyx.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func createCanvas() {
        Haptics.lightImpact()
        if canvases.createCanvas() != nil { newCanvasBounce.toggle() }
    }
}

#if DEBUG
#Preview("Canvas list") {
    NavigationStack {
        CanvasListView()
    }
    .previewEnvironment()
}

#Preview("Free tier") {
    NavigationStack {
        CanvasListView()
    }
    .previewEnvironment(hasOnyx: false)
}

#Preview("Empty") {
    NavigationStack {
        CanvasListView()
    }
    .previewEnvironment(seeded: false)
}
#endif
#endif
