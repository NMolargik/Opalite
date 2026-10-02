//
//  PortfolioStatusSync.swift
//  OpaliteCore
//
//  Keeps every mirror of the portfolio in step with the store by observing the one change
//  stream: the widget snapshot in the App Group, the paired watch, Spotlight, and Siri's
//  entity vocabulary. Bursts of changes coalesce into one push after `debounce`.
//

import Foundation
import os

@MainActor
public final class PortfolioStatusSync {
    private let loadColors: any LoadColors
    private let loadPalettes: any LoadPalettes
    private let observeChanges: any ObservePortfolioChanges
    private let widgetStorage: WidgetColorStorage
    private let widgets: (any WidgetTimelineReloading)?
    private let watch: (any WatchPortfolioPushing)?
    private let indexer: (any PortfolioIndexing)?
    private let vocabulary: (any ShortcutVocabularyUpdating)?
    private let debounce: Duration

    private var observationTask: Task<Void, Never>?
    private var pendingTask: Task<Void, Never>?
    private var lastFingerprint: [String]?

    public init(
        loadColors: any LoadColors,
        loadPalettes: any LoadPalettes,
        observeChanges: any ObservePortfolioChanges,
        widgetStorage: WidgetColorStorage,
        widgets: (any WidgetTimelineReloading)?,
        watch: (any WatchPortfolioPushing)?,
        indexer: (any PortfolioIndexing)?,
        vocabulary: (any ShortcutVocabularyUpdating)?,
        debounce: Duration = .milliseconds(750)
    ) {
        self.loadColors = loadColors
        self.loadPalettes = loadPalettes
        self.observeChanges = observeChanges
        self.widgetStorage = widgetStorage
        self.widgets = widgets
        self.watch = watch
        self.indexer = indexer
        self.vocabulary = vocabulary
        self.debounce = debounce
    }

    deinit {
        observationTask?.cancel()
        pendingTask?.cancel()
    }

    /// Pushes the current state once and starts observing. Safe to call more than once.
    public func start() {
        pushNow()
        guard observationTask == nil else { return }
        // Subscribe synchronously so a change notified before the task first runs is not lost.
        let stream = observeChanges()
        observationTask = Task { [weak self] in
            for await change in stream {
                guard let self else { return }
                if change.affectsPortfolio { self.schedulePush() }
            }
        }
    }

    /// Builds the current snapshot and pushes it to every mirror, unconditionally.
    public func pushNow() {
        do {
            let colors = try loadColors()
            let palettes = try loadPalettes()
            lastFingerprint = Self.fingerprint(colors: colors, palettes: palettes)
            push(colors: colors, palettes: palettes)
        } catch {
            Log.app.error("Status sync load failed: \(error.localizedDescription)")
        }
    }

    /// Pushes only when something the mirrors show actually changed.
    func pushIfNeeded() {
        do {
            let colors = try loadColors()
            let palettes = try loadPalettes()
            let fingerprint = Self.fingerprint(colors: colors, palettes: palettes)
            guard fingerprint != lastFingerprint else { return }
            lastFingerprint = fingerprint
            push(colors: colors, palettes: palettes)
        } catch {
            Log.app.error("Status sync load failed: \(error.localizedDescription)")
        }
    }

    /// The current watch snapshot (the watch relay asks for it on `requestSync`).
    public func currentSnapshot() -> WatchPortfolioSnapshot {
        guard let colors = try? loadColors(), let palettes = try? loadPalettes() else { return .empty }
        return WatchPortfolioSnapshot(models: colors, palettes: palettes)
    }

    private func push(colors: [OpaliteColor], palettes: [OpalitePalette]) {
        widgetStorage.saveColors(colors.map { WidgetColor(id: $0.id, name: $0.name, red: $0.red, green: $0.green, blue: $0.blue, alpha: $0.alpha) })
        widgets?.reloadAllTimelines()
        watch?.push(WatchPortfolioSnapshot(models: colors, palettes: palettes))
        indexer?.reindex(colors: colors, palettes: palettes)
        vocabulary?.updateAppShortcutParameters()
    }

    private func schedulePush() {
        pendingTask?.cancel()
        pendingTask = Task { [weak self, debounce] in
            do { try await Task.sleep(for: debounce) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.pendingTask = nil
            self.pushIfNeeded()
        }
    }

    /// Mirrors the fields the widgets, watch, and Spotlight actually show.
    static func fingerprint(colors: [OpaliteColor], palettes: [OpalitePalette]) -> [String] {
        colors.map { "\($0.id)|\($0.name ?? "")|\($0.hexString)|\($0.alpha)|\($0.palette?.id.uuidString ?? "")|\($0.updatedAt.timeIntervalSince1970)" }
            + palettes.map { "P|\($0.id)|\($0.name)|\($0.isArchived)|\($0.updatedAt.timeIntervalSince1970)" }
    }
}
