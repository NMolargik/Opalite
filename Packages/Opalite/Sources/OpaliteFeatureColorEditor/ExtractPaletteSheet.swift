//
//  ExtractPaletteSheet.swift
//  OpaliteFeatureColorEditor
//
//  "Extract Palette": pull a whole palette out of a photo (Photos, camera, or a file on Mac)
//  or a website the user types. The swatches can be deselected, the count changed, and the
//  result saved as a new palette (named from the file or the site) or added to an existing one.
//  Free for everyone; creating a new palette follows the usual free-tier palette limit.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteServices
import UIKit
import os

public struct ExtractPaletteSheet: View {
    private let initialImage: PlatformImage?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onyxEntitlement) private var entitlement
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ToastManager.self) private var toasts

    private enum Source: String, CaseIterable, Identifiable {
        case photo, website
        var id: Self { self }
    }

    private enum Phase: Equatable {
        case idle
        case working
        case failed(String)
        case ready
    }

    /// Where the selected colors go; `nil` id means a new palette.
    private enum Destination: Hashable {
        case new
        case existing(UUID)
    }

    @State private var source: Source = .photo
    @State private var image: UIImage?
    @State private var imageName: String?
    @State private var urlText = ""
    @State private var phase: Phase = .idle
    @State private var samples = PaletteSamples()
    @State private var suggestedName = ""
    @State private var count = 5
    @State private var extracted: [ExtractedColor] = []
    @State private var deselected: Set<String> = []
    @State private var destination: Destination = .new
    @State private var paletteName = ""
    @State private var task: Task<Void, Never>?
    @State private var isDropTargeted = false
    @FocusState private var isURLFocused: Bool

    public init(image: PlatformImage? = nil) {
        self.initialImage = image
    }

    private var selected: [ExtractedColor] { extracted.filter { !deselected.contains($0.id) } }
    private var isAtPaletteLimit: Bool { !OnyxGate(hasOnyx: entitlement.hasOnyx).canCreatePalette(currentCount: portfolio.palettes.count) }
    private var canSave: Bool {
        guard !selected.isEmpty else { return false }
        if case .new = destination { return !paletteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return true
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.lg) {
                    Picker(selection: $source) {
                        Text("Photo").tag(Source.photo)
                        Text("Website").tag(Source.website)
                    } label: {
                        Text("Source")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("extractPalette.source")

                    switch source {
                    case .photo: photoSource
                    case .website: websiteSource
                    }

                    if case .failed(let message) = phase {
                        failureCard(message)
                    }

                    if !extracted.isEmpty {
                        resultCard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        destinationCard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(Brand.Space.lg)
                .frame(maxWidth: Brand.detailMaxWidth)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: extracted)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: phase)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: source)
            }
            .softScrollEdgesIfAvailable()
            .scrollDismissesKeyboard(.interactively)
            .background(groupedBackground.ignoresSafeArea())
            .navigationTitle(Text("Extract Palette"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                    .accessibilityIdentifier("extractPalette.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("extractPalette.save")
                }
            }
            .dropDestination(for: Data.self) { items, _ in
                guard let data = items.first, let dropped = UIImage(data: data) else { return false }
                source = .photo
                setImage(dropped, name: nil)
                return true
            } isTargeted: { isDropTargeted = $0 }
        }
        .onAppear {
            if image == nil, let initialImage { setImage(initialImage, name: nil) }
            if destination == .new, paletteName.isEmpty { paletteName = defaultName }
        }
        .onDisappear { task?.cancel() }
        .onChange(of: source) { _, _ in
            // Each source keeps its own result; switching just re-applies it.
            task?.cancel()
            phase = .idle
            samples = PaletteSamples()
            extracted = []
            deselected = []
            if source == .photo, let image { analyze(image: image) }
        }
        .onChange(of: suggestedName) { _, _ in
            if case .new = destination { paletteName = defaultName }
        }
    }

    private var defaultName: String {
        suggestedName.isEmpty ? String(localized: "Extracted Palette") : suggestedName
    }

    // MARK: - Photo

    private var photoSource: some View {
        VStack(spacing: Brand.Space.md) {
            #if targetEnvironment(macCatalyst)
            ImageSourceBar(onImage: { setImage($0, name: nil) }, allowsFileImport: true, onFileName: { imageName = $0 })
            #else
            ImageSourceBar(onImage: { setImage($0, name: nil) })
            #endif

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous).strokeBorder(.quaternary))
                    .accessibilityLabel(Text("Chosen image"))
            } else {
                ImageDropPlaceholder(isTargeted: isDropTargeted, buildsPalette: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Website

    private var websiteSource: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            Text("Website address")
                .font(.headline)
            TextField(String(localized: "example.com"), text: $urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textContentType(.URL)
                .submitLabel(.go)
                .focused($isURLFocused)
                .onSubmit(readWebsite)
                .padding(Brand.Space.md)
                .background(groupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
                .accessibilityIdentifier("extractPalette.url")

            Button(action: readWebsite) {
                Group {
                    if phase == .working {
                        HStack(spacing: Brand.Space.sm) {
                            ProgressView()
                            Text("Reading the page")
                        }
                    } else {
                        Label("Extract Colors", systemImage: "globe")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .primaryActionButton(tint: .opalitePurple)
            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phase == .working)
            .accessibilityIdentifier("extractPalette.readSite")

            Text("Opalite fetches only this page and its stylesheets, then renders it to sample its colors. Like a browser, rendering also loads the page's own images and fonts. Your palettes never leave your device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Brand.Space.lg)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }

    private func failureCard(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .padding(Brand.Space.lg)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .accessibilityIdentifier("extractPalette.error")
    }

    // MARK: - Result

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            HStack {
                Label {
                    Text("Colors")
                } icon: {
                    Image(systemName: "swatchpalette.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.opalitePurpleInk)
                }
                .font(.headline)
                Spacer()
                Text("\(selected.count) of \(extracted.count) selected")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 110), spacing: Brand.Space.md)], spacing: Brand.Space.md) {
                ForEach(extracted) { color in
                    swatch(color)
                }
            }

            Stepper(value: $count, in: PaletteExtractor.countRange) {
                Text("Number of colors: \(count)")
                    .monospacedDigit()
            }
            .onChange(of: count) { _, _ in reextract() }
            .accessibilityIdentifier("extractPalette.count")
        }
        .padding(Brand.Space.lg)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }

    private func swatch(_ color: ExtractedColor) -> some View {
        let isSelected = !deselected.contains(color.id)
        return Button {
            Haptics.selection()
            if isSelected { deselected.insert(color.id) } else { deselected.remove(color.id) }
        } label: {
            VStack(spacing: Brand.Space.xs) {
                RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                    .fill(color.rgba.color)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(color.rgba.idealTextColor)
                        }
                    }
                    .opacity(isSelected ? 1 : 0.35)
                Text(color.rgba.hexString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .hoverLift()
        .accessibilityLabel(Text("\(color.rgba.hexString), \(ColorClassifier.description(of: color.rgba))"))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .accessibilityHint(Text("Double tap to include or leave out this color"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Destination

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            HStack {
                Label {
                    Text("Save To")
                } icon: {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.opalitePurpleInk)
                }
                .font(.headline)
                if destination == .new, isAtPaletteLimit { OnyxBadge(compact: true) }
                Spacer()
                Picker(selection: $destination) {
                    Text("New Palette").tag(Destination.new)
                    if !portfolio.orderedPalettes.isEmpty {
                        Section("Add to Existing") {
                            ForEach(portfolio.orderedPalettes) { palette in
                                Text(palette.name).tag(Destination.existing(palette.id))
                            }
                        }
                    }
                } label: {
                    Text("Destination")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityIdentifier("extractPalette.destination")
            }

            if destination == .new {
                TextField(String(localized: "Palette name"), text: $paletteName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(Brand.Space.md)
                    .background(groupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
                    .accessibilityIdentifier("extractPalette.name")
                if isAtPaletteLimit {
                    Text("Free accounts can keep \(OnyxGate.freePaletteLimit) palettes. Add to an existing palette, or get Onyx for more.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Brand.Space.lg)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }

    // MARK: - Actions

    private func setImage(_ new: UIImage, name: String?) {
        image = new
        if let name { imageName = name }
        suggestedName = imageName.map { $0.isEmpty ? "" : $0 } ?? String(localized: "Photo Palette")
        analyze(image: new)
    }

    private func analyze(image: UIImage) {
        guard let cgImage = image.sampleableCGImage(maxDimension: 512) else {
            phase = .failed(String(localized: "That image couldn't be read."))
            return
        }
        suggestedName = imageName ?? String(localized: "Photo Palette")
        samples = ImagePaletteSampler.samples(from: cgImage)
        finishExtraction()
    }

    private func readWebsite() {
        guard phase != .working else { return }
        let text = urlText
        isURLFocused = false
        task?.cancel()
        phase = .working
        extracted = []
        deselected = []
        task = Task {
            do {
                let result = try await WebsitePaletteService().extract(from: text)
                guard !Task.isCancelled else { return }
                suggestedName = result.host
                samples = result.samples
                finishExtraction()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                Log.app.error("Website palette failed: \(error.localizedDescription)")
                extracted = []
                phase = .failed((error as? LocalizedError)?.errorDescription ?? String(localized: "Opalite couldn't read that website."))
                Haptics.warning()
            }
        }
    }

    private func finishExtraction() {
        let result = samples.palette(count: count)
        if result.isEmpty {
            extracted = []
            phase = .failed(String(localized: "No colors could be found in that image."))
            return
        }
        extracted = result
        deselected = []
        phase = .ready
        if case .new = destination { paletteName = defaultName }
        Haptics.lightImpact()
    }

    private func reextract() {
        guard !samples.isEmpty else { return }
        extracted = samples.palette(count: count)
        deselected = []
    }

    private func save() {
        let colors = selected
        guard !colors.isEmpty else { return }
        let palette: OpalitePalette?
        switch destination {
        case .new:
            palette = portfolio.createPalette(name: paletteName.trimmingCharacters(in: .whitespacesAndNewlines))
            // At the free limit createPalette has already toasted the Get Onyx prompt.
            guard palette != nil else { Haptics.warning(); return }
        case .existing(let id):
            palette = portfolio.palette(withID: id)
            guard palette != nil else { return }
        }
        for color in colors { portfolio.createColor(color.rgba, in: palette) }
        Haptics.success()
        if let palette {
            toasts.showSuccess(String(localized: "Saved \(colors.count) colors to \(palette.name)"), systemImage: "swatchpalette.fill")
        }
        dismiss()
    }
}

#if DEBUG
#Preview("Extract palette") {
    let image = ImageRendering.uiImage(LinearGradient.opalite, size: CGSize(width: 600, height: 400))
    return ExtractPaletteSheet(image: image)
        .previewEnvironment()
}
#endif
#endif
