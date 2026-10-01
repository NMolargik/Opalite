//
//  SwatchBarView.swift
//  OpaliteFeatureSwatchBar
//
//  The SwatchBar: a narrow, tall secondary window (iPad, Mac, visionOS) the user parks
//  beside other apps. It lists every palette and the loose colors as compact swatches;
//  tapping one copies its hex and hands the color to any open canvas as the ink color.
//  A quick-add field at the bottom turns a typed hex into a new color, and ⌘N opens the
//  full editor. The shell hosts this in `WindowGroup(id: "swatchBar")` and injects the
//  environment.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureColorEditor

public struct SwatchBarView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(CanvasModel.self) private var canvases
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(ToastManager.self) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model = SwatchBarViewModel()
    @State private var isSearchPresented = false
    @State private var isPresentingEditor = false
    @State private var editingColor: OpaliteColor?
    @State private var copiedColorID: UUID?
    @State private var copiedResetTask: Task<Void, Never>?
    @State private var quickAddShake = 0
    @FocusState private var quickAddFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("SwatchBar")
                .toolbarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .searchable(text: $model.query, isPresented: $isSearchPresented, prompt: Text("Name or hex"))
                .minimizingSearchIfAvailable()
                .safeAreaInset(edge: .bottom, spacing: 0) { quickAddBar }
        }
        .toastContainer()
        .sheet(isPresented: $isPresentingEditor) {
            ColorEditorView(mode: .create()) {
                isPresentingEditor = false
            } onSave: { result in
                isPresentingEditor = false
                if let color = portfolio.createColor(result.rgba, name: result.name, notes: result.notes) {
                    Haptics.success()
                    toasts.showSuccess(String(localized: "Added \(color.displayName)"), systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $editingColor) { color in
            ColorEditorView(mode: .edit(color)) {
                editingColor = nil
            } onSave: { result in
                editingColor = nil
                portfolio.update(color) {
                    $0.red = result.rgba.red
                    $0.green = result.rgba.green
                    $0.blue = result.rgba.blue
                    $0.alpha = result.rgba.alpha
                    $0.name = result.name
                    $0.notes = result.notes
                }
                Haptics.success()
            }
        }
        .confirmationDialog("Copy hex codes with the # prefix?", isPresented: hexPreferenceBinding, titleVisibility: .visible) {
            Button("Include #") { hexCopy.choosePrefix(true) }
            Button("Just the digits") { hexCopy.choosePrefix(false) }
        } message: {
            Text("You can change this later in Settings.")
        }
    }

    // MARK: - Content

    @ContentBuilder
    private var content: some View {
        let sections = model.sections(from: portfolio)

        if portfolio.colors.isEmpty {
            emptyState
        } else if sections.isEmpty {
            ContentUnavailableView.search(text: model.query)
                .background(windowBackground)
        } else {
            ScrollView {
                LazyVStack(spacing: Brand.Space.sm, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            if model.isExpanded(section.kind) {
                                swatchGrid(for: section)
                                    .padding(.horizontal, Brand.Space.md)
                                    .padding(.bottom, Brand.Space.sm)
                                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
                            }
                        } header: {
                            sectionHeader(section)
                        }
                    }
                }
                .padding(.top, Brand.Space.xs)
                .padding(.bottom, Brand.Space.md)
                .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: model.collapsedSections)
                .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: model.swatchSize)
            }
            .dismissesKeyboardOnScroll()
            .softScrollEdgesIfAvailable()
            .background(windowBackground)
        }
    }

    private var windowBackground: some View {
        ZStack {
            groupedBackground
            LinearGradient.opaliteWash.opacity(0.6)
        }
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        EmptyStateView(
            "No Colors Yet",
            systemImage: "swatchpalette",
            description: String(localized: "Colors and palettes you create in Opalite appear here, ready to copy or paint with.")
        ) {
            Button {
                Haptics.selection()
                isPresentingEditor = true
            } label: {
                Label("New Color", systemImage: "plus")
            }
            .primaryActionButton()
            .accessibilityIdentifier("swatchBar.emptyState.newColor")
        }
        .background(windowBackground)
    }

    // MARK: - Sections

    private func sectionHeader(_ section: SwatchBarSection) -> some View {
        let expanded = model.isExpanded(section.kind)
        return Button {
            Haptics.selection()
            model.toggle(section.kind)
        } label: {
            HStack(spacing: Brand.Space.sm) {
                Image(systemName: section.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.opalitePurple)
                    .accessibilityHidden(true)
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Brand.Space.xs)
                Text(section.count, format: .number)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityHidden(true)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.sm)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.isSearching)
        .adaptiveGlassCapsule()
        .padding(.horizontal, Brand.Space.md)
        .padding(.vertical, Brand.Space.xs)
        .hoverHighlight()
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(Text("\(section.title), \(section.count) colors"))
        .accessibilityValue(expanded ? Text("Expanded") : Text("Collapsed"))
        .accessibilityHint(model.isSearching ? Text("") : Text("Double-tap to \(expanded ? "collapse" : "expand")"))
        .accessibilityIdentifier("swatchBar.section.\(section.title)")
    }

    private func swatchGrid(for section: SwatchBarSection) -> some View {
        let size = model.swatchSize
        let columns = [GridItem(.adaptive(minimum: size.minimumSide), spacing: Brand.Space.sm)]
        return LazyVGrid(columns: columns, spacing: Brand.Space.sm) {
            ForEach(section.colors) { color in
                swatchCell(for: color, size: size)
            }
        }
    }

    // MARK: - Swatches

    private func swatchCell(for color: OpaliteColor, size: SwatchBarSwatchSize) -> some View {
        let badge = size.showsHexInBadge && color.hasName ? "\(color.displayName) · \(color.hexString)" : color.displayName
        let isCopied = copiedColorID == color.id

        return SwatchView(
            color: color,
            height: size.height,
            cornerRadius: size == .compact ? Brand.Radius.chip : Brand.Radius.swatch,
            showsOverlays: size.showsOverlays,
            badgeText: badge,
            menu: {
                swatchMenu(for: color)
            }
        )
        .if(size == .compact) { $0.aspectRatio(1, contentMode: .fit) }
        .overlay {
            if isCopied {
                copiedOverlay(for: color, size: size)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
        .onTapGesture { pick(color) }
        .hoverLift()
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Copies the hex code and sets the canvas ink color"))
        .accessibilityIdentifier("swatchBar.swatch.\(color.id.uuidString)")
    }

    private func copiedOverlay(for color: OpaliteColor, size: SwatchBarSwatchSize) -> some View {
        RoundedRectangle(cornerRadius: size == .compact ? Brand.Radius.chip : Brand.Radius.swatch, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                Image(systemName: "checkmark")
                    .font(size == .compact ? .body.weight(.bold) : .title2.weight(.bold))
                    .foregroundStyle(color.idealTextColor())
                    .if(!reduceMotion) { $0.symbolEffect(.bounce, value: copiedColorID) }
            }
            .transition(reduceMotion ? .identity : .opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ContentBuilder
    private func swatchMenu(for color: OpaliteColor) -> some View {
        Section(color.hasName ? "\(color.displayName) · \(color.hexString)" : color.hexString) {
            Button {
                copyWithFeedback(color)
            } label: {
                Label("Copy Hex", systemImage: "number")
            }
            Button {
                hexCopy.copy(text: color.rgbString, label: color.rgbString)
            } label: {
                Label("Copy RGB", systemImage: "slider.horizontal.3")
            }
        }
        Button {
            Haptics.selection()
            canvases.selectedInkColor = color.rgba
            toasts.show(message: String(localized: "Ink set to \(color.displayName)"), style: .info, systemImage: "paintbrush.pointed.fill")
        } label: {
            Label("Use as Ink Color", systemImage: "paintbrush.pointed")
        }
        Button {
            Haptics.selection()
            editingColor = color
        } label: {
            Label("Edit Color", systemImage: "slider.horizontal.below.square.filled.and.square")
        }
    }

    /// The tap: copy the hex and make it the canvas ink color.
    private func pick(_ color: OpaliteColor) {
        copyWithFeedback(color)
        canvases.selectedInkColor = color.rgba
    }

    private func copyWithFeedback(_ color: OpaliteColor) {
        hexCopy.copyHex(for: color)
        copiedResetTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.12)) {
            copiedColorID = color.id
        }
        copiedResetTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                copiedColorID = nil
            }
        }
    }

    // MARK: - Quick add

    private var quickAddBar: some View {
        let state = model.quickAddState(in: portfolio)
        return VStack(alignment: .leading, spacing: Brand.Space.xs) {
            HStack(spacing: Brand.Space.sm) {
                quickAddPreview(state)
                TextField("Add a hex, like 4A90E2", text: $model.quickAddText)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($quickAddFocused)
                    .onSubmit(submitQuickAdd)
                    .accessibilityLabel(Text("Hex code"))
                    .accessibilityHint(Text("Type a hex code and press return to add it as a new color"))
                    .accessibilityIdentifier("swatchBar.quickAdd.field")
                Button(action: submitQuickAdd) {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(state.isValid ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .disabled(!state.isValid)
                .accessibilityLabel(Text("Add color"))
                .accessibilityIdentifier("swatchBar.quickAdd.add")
            }
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.sm)
            .adaptiveGlass(cornerRadius: Brand.Radius.control)
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: quickAddShake) { content, offset in
                content.offset(x: reduceMotion ? 0 : offset)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-8, duration: 0.06)
                    CubicKeyframe(8, duration: 0.06)
                    CubicKeyframe(-5, duration: 0.06)
                    CubicKeyframe(5, duration: 0.06)
                    CubicKeyframe(0, duration: 0.06)
                }
            }

            if let hint = quickAddHint(state) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(state == .invalid ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, Brand.Space.sm)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityIdentifier("swatchBar.quickAdd.hint")
            }
        }
        .padding(.horizontal, Brand.Space.md)
        .padding(.top, Brand.Space.sm)
        .padding(.bottom, Brand.Space.md)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: state)
        .tint(.opalitePurple)
    }

    @ContentBuilder
    private func quickAddPreview(_ state: SwatchBarQuickAddState) -> some View {
        if let rgba = state.rgba {
            ColorChip(rgba, size: 28)
                .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
                .accessibilityLabel(Text("Preview, \(rgba.hexString)"))
        } else {
            Image(systemName: "number")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
    }

    private func quickAddHint(_ state: SwatchBarQuickAddState) -> String? {
        switch state {
        case .empty: nil
        case .incomplete: String(localized: "Enter 3, 6, or 8 hex digits")
        case .invalid: String(localized: "Hex codes use only 0–9 and A–F")
        case .valid(_, _, let duplicate):
            duplicate.map { String(localized: "Already saved as \($0)") }
        }
    }

    private func submitQuickAdd() {
        if let color = model.submitQuickAdd(into: portfolio) {
            Haptics.success()
            toasts.showSuccess(String(localized: "Added \(color.hexString)"), systemImage: "plus.circle.fill")
        } else if !model.quickAddText.isEmpty {
            Haptics.warning()
            quickAddShake += 1
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.selection()
                isPresentingEditor = true
            } label: {
                Label("New Color", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .toolbarButtonTint()
            .accessibilityIdentifier("swatchBar.newColor")
        }

        ToolbarSpacerIfAvailable(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Swatch Size", selection: $model.swatchSize) {
                    ForEach(SwatchBarSwatchSize.allCases) { size in
                        Label(size.title, systemImage: size.systemImage).tag(size)
                    }
                }
                .pickerStyle(.inline)

                Divider()

                Button {
                    Haptics.selection()
                    model.cycleSwatchSize()
                } label: {
                    Label("Next Swatch Size", systemImage: model.swatchSize.next.systemImage)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button {
                    Haptics.selection()
                    model.toggleAll(in: portfolio)
                } label: {
                    if model.allExpanded(in: portfolio) {
                        Label("Collapse All", systemImage: "rectangle.compress.vertical")
                    } else {
                        Label("Expand All", systemImage: "rectangle.expand.vertical")
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.isSearching)

                Button {
                    isSearchPresented = true
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)

                Button {
                    quickAddFocused = true
                } label: {
                    Label("Add by Hex", systemImage: "number")
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .toolbarButtonTint()
            .accessibilityIdentifier("swatchBar.more")
        }
    }

    // MARK: - Hex preference

    private var hexPreferenceBinding: Binding<Bool> {
        Binding(
            get: { hexCopy.isAskingPreference },
            set: { if !$0 { hexCopy.isAskingPreference = false } }
        )
    }
}

// MARK: - Platform helpers

extension View {
    /// Interactive keyboard dismissal while scrolling (iOS/iPadOS only; visionOS has no such modifier).
    @ContentBuilder
    fileprivate func dismissesKeyboardOnScroll() -> some View {
        #if os(iOS)
        scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}

// MARK: - Previews

#if DEBUG
#Preview("SwatchBar") {
    SwatchBarView()
        .frame(width: 250, height: 700)
        .previewEnvironment()
}

#Preview("SwatchBar · wide") {
    SwatchBarView()
        .frame(width: 520, height: 700)
        .previewEnvironment()
}

#Preview("SwatchBar · empty") {
    SwatchBarView()
        .frame(width: 250, height: 600)
        .previewEnvironment(seeded: false)
}
#endif
#endif
