//
//  CanvasModel.swift
//  OpaliteFeatureShared
//
//  The environment-injected canvas surface (successor to CanvasManager): the cached
//  canvas list, which canvas the shell should open next, the pending shape from the menu
//  bar, the ink color picked in the SwatchBar, and the persistence verbs (each through a
//  use-case, toasting on failure, with the free-tier gate routing to the paywall).
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import os
#if canImport(PencilKit)
import PencilKit
#endif

@MainActor
@Observable
public final class CanvasModel {
    @ObservationIgnored private let loadCanvases: any LoadCanvases
    @ObservationIgnored private let findCanvasUseCase: any FindCanvas
    @ObservationIgnored private let createCanvasUseCase: any CreateCanvas
    @ObservationIgnored private let updateCanvasUseCase: any UpdateCanvas
    @ObservationIgnored private let deleteCanvasUseCase: any DeleteCanvas
    @ObservationIgnored private let observeChanges: any ObservePortfolioChanges
    @ObservationIgnored private let entitlements: any EntitlementProviding
    @ObservationIgnored private let device: any DeviceDescribing
    @ObservationIgnored private let toastManager: ToastManager
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let thumbnailRenderer: (@MainActor (CanvasFile) -> Data?)?

    /// Every canvas, alphabetical.
    public private(set) var canvases: [CanvasFile] = []
    public private(set) var changeStamp = 0

    /// A canvas the shell should navigate to (new canvas, menu bar, deep link).
    public var pendingCanvasID: UUID?
    /// A shape the active canvas should start placing (menu bar).
    public var pendingShape: CanvasShape?
    /// The ink color chosen in the SwatchBar for the active canvas.
    public var selectedInkColor: RGBA?

    @ObservationIgnored private var observationTask: Task<Void, Never>?

    public init(
        loadCanvases: any LoadCanvases,
        findCanvas: any FindCanvas,
        createCanvas: any CreateCanvas,
        updateCanvas: any UpdateCanvas,
        deleteCanvas: any DeleteCanvas,
        observeChanges: any ObservePortfolioChanges,
        entitlements: any EntitlementProviding,
        device: any DeviceDescribing = GenericDevice(),
        toastManager: ToastManager,
        router: AppRouter,
        thumbnailRenderer: (@MainActor (CanvasFile) -> Data?)? = nil
    ) {
        self.loadCanvases = loadCanvases
        self.findCanvasUseCase = findCanvas
        self.createCanvasUseCase = createCanvas
        self.updateCanvasUseCase = updateCanvas
        self.deleteCanvasUseCase = deleteCanvas
        self.observeChanges = observeChanges
        self.entitlements = entitlements
        self.device = device
        self.toastManager = toastManager
        self.router = router
        self.thumbnailRenderer = thumbnailRenderer
        refresh()
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let stream = self?.observeChanges() else { return }
            for await change in stream {
                guard let self else { return }
                if change.affectsCanvases { self.refresh() }
            }
        }
    }

    // MARK: - Reads

    public func refresh() {
        do {
            canvases = try loadCanvases()
            changeStamp &+= 1
        } catch {
            Log.canvas.error("Canvas refresh failed: \(error.localizedDescription)")
            toastManager.show(error: error)
        }
    }

    public func canvas(withID id: UUID) -> CanvasFile? {
        if let cached = canvases.first(where: { $0.id == id }) { return cached }
        return (try? findCanvasUseCase(withID: id)) ?? nil
    }

    /// The oldest canvas — the one the free tier can open.
    public var oldestCanvas: CanvasFile? { canvases.min { $0.createdAt < $1.createdAt } }

    public var gate: OnyxGate { OnyxGate(hasOnyx: entitlements.hasOnyx) }

    /// Whether the user may open this canvas (free tier: only the oldest).
    public func canAccess(_ canvas: CanvasFile) -> Bool {
        gate.canAccessCanvas(id: canvas.id, oldestCanvasID: oldestCanvas?.id)
    }

    public var canCreateCanvas: Bool { gate.canCreateCanvas(currentCount: canvases.count) }

    // MARK: - Writes

    /// Creates a canvas and stages it for opening; nil on limit (paywall shown) or failure.
    @discardableResult
    public func createCanvas(title: String = String(localized: "Untitled Canvas")) -> CanvasFile? {
        do {
            let canvas = try createCanvasUseCase(title: title, deviceName: device.deviceName)
            refresh()
            pendingCanvasID = canvas.id
            return canvas
        } catch CanvasCreationError.limitReached {
            toastManager.show(error: OpaliteError.canvasLimitReached, actionTitle: String(localized: "Get Onyx")) { [router] in
                router.requestPaywall(context: OpaliteError.canvasLimitReached.errorDescription ?? "")
            }
            return nil
        } catch {
            toastManager.show(error: error)
            return nil
        }
    }

    public func update(_ canvas: CanvasFile, configure: (CanvasFile) -> Void) {
        do {
            try updateCanvasUseCase(canvas, deviceName: device.deviceName, configure: configure)
            refresh()
        } catch {
            Log.canvas.error("Canvas update failed: \(error.localizedDescription)")
            toastManager.show(error: error)
        }
    }

    public func rename(_ canvas: CanvasFile, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(canvas) { $0.title = trimmed }
    }

    public func delete(_ canvas: CanvasFile) {
        if pendingCanvasID == canvas.id { pendingCanvasID = nil }
        do {
            try deleteCanvasUseCase(canvas)
            refresh()
        } catch {
            toastManager.show(error: error)
        }
    }

    /// Opens a canvas if the tier allows it, otherwise shows the paywall.
    public func requestOpen(_ canvas: CanvasFile) {
        if canAccess(canvas) {
            pendingCanvasID = canvas.id
        } else {
            router.requestPaywall(context: OpaliteError.canvasLimitReached.errorDescription ?? "")
        }
    }

    #if canImport(PencilKit)
    /// Persists a drawing and regenerates the thumbnail.
    public func saveDrawing(_ drawing: PKDrawing, to canvas: CanvasFile) {
        update(canvas) { file in
            file.saveDrawing(drawing)
            file.thumbnailData = thumbnailRenderer?(file) ?? file.thumbnailData
        }
    }

    public func loadDrawing(from canvas: CanvasFile) -> PKDrawing {
        (self.canvas(withID: canvas.id) ?? canvas).loadDrawing()
    }
    #endif
}
