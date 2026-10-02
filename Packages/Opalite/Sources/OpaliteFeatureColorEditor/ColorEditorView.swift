//
//  ColorEditorView.swift
//  OpaliteFeatureColorEditor
//
//  The app's signature screen: a large live swatch with its readouts, a glass mode
//  picker, and six ways to pick a color. Compact widths stack the swatch over the mode
//  content; regular widths put them side by side. Hosts present it (usually as a sheet)
//  and receive a `ColorEditorResult` on Save.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteServices

public struct ColorEditorView: View {
    private let onCancel: () -> Void
    private let onSave: (ColorEditorResult) -> Void

    @State private var viewModel: ColorEditorViewModel
    @State private var previewColor: OpaliteColor
    @State private var isEditingName = false
    @State private var contentSize: CGSize = .zero
    @State private var modeAreaHeight: CGFloat = 0

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ColorNameSuggestionService.self) private var namer: ColorNameSuggestionService?
    @ScaledMetric(relativeTo: .body) private var compactSwatchHeight: CGFloat = 190

    public init(mode: ColorEditorMode, onCancel: @escaping () -> Void, onSave: @escaping (ColorEditorResult) -> Void) {
        self.onCancel = onCancel
        self.onSave = onSave
        let viewModel = ColorEditorViewModel(mode: mode)
        _viewModel = State(initialValue: viewModel)
        let rgba = viewModel.rgba
        _previewColor = State(initialValue: OpaliteColor(name: viewModel.name.isEmpty ? nil : viewModel.name, red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha))
    }

    private var isRegular: Bool { horizontalSizeClass == .regular && contentSize.width >= 700 }
    /// Shorter phones get a shorter swatch so the mode content keeps room to breathe.
    private var swatchHeight: CGFloat { contentSize.height > 0 && contentSize.height < 720 ? compactSwatchHeight * 0.72 : compactSwatchHeight }

    public var body: some View {
        NavigationStack {
            Group {
                if isRegular { regularLayout } else { compactLayout }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
            .background(groupedBackground.ignoresSafeArea())
            .navigationTitle(viewModel.isEditing ? Text("Edit Color") : Text("New Color"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .background { keyboardShortcuts }
        }
        .onChange(of: viewModel.rgba) { _, rgba in
            previewColor.red = rgba.red
            previewColor.green = rgba.green
            previewColor.blue = rgba.blue
            previewColor.alpha = rgba.alpha
        }
        .onChange(of: viewModel.name) { _, name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            previewColor.name = trimmed.isEmpty ? nil : trimmed
        }
        .onChange(of: isEditingName) { _, editing in
            if editing, let namer {
                viewModel.loadNameSuggestions(using: namer)
            } else {
                viewModel.clearNameSuggestions()
            }
        }
    }

    // MARK: - Layouts

    private var compactLayout: some View {
        VStack(spacing: 0) {
            ColorEditorSwatchPanel(viewModel: viewModel, previewColor: previewColor, isEditingName: $isEditingName, compact: true, swatchHeight: swatchHeight)
                .padding(.horizontal, Brand.Space.lg)
                .padding(.top, Brand.Space.sm)

            ScrollView {
                modeContent(fillsHeight: false)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.lg)
                    .frame(maxWidth: Brand.detailMaxWidth)
                    .frame(maxWidth: .infinity)
            }
            .dismissingKeyboardOnScroll()
            .softScrollEdgesIfAvailable()
        }
        .safeAreaInset(edge: .bottom) { modePicker }
    }

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: Brand.Space.xl) {
            ColorEditorSwatchPanel(viewModel: viewModel, previewColor: previewColor, isEditingName: $isEditingName, compact: false)
                .frame(width: min(max(contentSize.width * 0.38, 300), 460))

            VStack(spacing: Brand.Space.lg) {
                ScrollView {
                    modeContent(fillsHeight: true)
                        .padding(.vertical, Brand.Space.xs)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(modeAreaHeight - Brand.Space.xs * 2, 320))
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { modeAreaHeight = $0 }
                .dismissingKeyboardOnScroll()
                .softScrollEdgesIfAvailable()
                modePicker
            }
        }
        .padding(Brand.Space.xl)
        .frame(maxWidth: 1240)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modePicker: some View {
        ModePicker(selection: viewModel.mode) { select($0) }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.vertical, Brand.Space.sm)
            .frame(maxWidth: .infinity)
    }

    @ContentBuilder
    private func modeContent(fillsHeight: Bool) -> some View {
        Group {
            switch viewModel.mode {
            case .spectrum: SpectrumPickerView(viewModel: viewModel, fillsHeight: fillsHeight)
            case .grid: GridPickerView(viewModel: viewModel)
            case .shuffle: ShufflePickerView(viewModel: viewModel, fillsHeight: fillsHeight)
            case .sliders: ChannelsPickerView(viewModel: viewModel)
            case .codes: CodesPickerView(viewModel: viewModel)
            case .image: ImagePickerView(viewModel: viewModel, fillsHeight: fillsHeight)
            }
        }
        .id(viewModel.mode)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: viewModel.mode)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel) {
                Haptics.selection()
                onCancel()
            } label: {
                Text("Cancel")
            }
            .accessibilityIdentifier("colorEditor.cancel")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.lightImpact()
                withAnimation(reduceMotion ? nil : .snappy) { viewModel.undo() }
            } label: {
                Label("Undo Last Pick", systemImage: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .toolbarButtonTint()
            .accessibilityIdentifier("colorEditor.undo")
        }

        if !viewModel.siblingColors.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    viewModel.isShowingPaletteStrip.toggle()
                } label: {
                    Label(
                        viewModel.isShowingPaletteStrip ? "Hide Palette Colors" : "Show Palette Colors",
                        systemImage: viewModel.isShowingPaletteStrip ? "swatchpalette.fill" : "swatchpalette"
                    )
                    .contentTransition(.symbolEffect(.replace))
                }
                .toolbarButtonTint()
                .accessibilityIdentifier("colorEditor.paletteStrip")
            }
        }

        ToolbarSpacerIfAvailable(.fixed, placement: .topBarTrailing)

        // Number pads have no return key and the notes field's return inserts a newline,
        // so every field gets the same way out.
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                Keyboard.dismiss()
            }
            .fontWeight(.semibold)
            .accessibilityIdentifier("colorEditor.keyboardDone")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button {
                Haptics.success()
                onSave(viewModel.result)
            } label: {
                Text("Save")
                    .fontWeight(.semibold)
            }
            .disabled(!viewModel.canSave)
            .keyboardShortcut("s", modifiers: .command)
            .accessibilityHint(viewModel.canSave ? Text("Saves the color") : Text("Make a change first"))
            .accessibilityIdentifier("colorEditor.save")
        }
    }

    /// Invisible buttons that give the modes their 1–6 shortcuts on iPad and Mac.
    private var keyboardShortcuts: some View {
        ForEach(ColorPickerTab.allCases) { tab in
            Button("") { select(tab) }
                .keyboardShortcut(KeyEquivalent(tab.keyboardShortcutKey), modifiers: [])
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private func select(_ tab: ColorPickerTab) {
        guard tab != viewModel.mode else { return }
        isEditingName = false
        viewModel.select(tab)
    }
}

#if DEBUG
#Preview("New color") {
    ColorEditorView(mode: .create(), onCancel: {}, onSave: { _ in })
        .previewEnvironment()
}

#Preview("Edit in palette") {
    let palette = OpalitePalette.sample
    let color = palette.colors!.first!
    color.palette = palette
    return ColorEditorView(mode: .edit(color), onCancel: {}, onSave: { _ in })
        .previewEnvironment()
}

#Preview("Sheet") {
    struct Preview: View {
        @State private var isPresented = true
        var body: some View {
            Button("Open Editor") { isPresented = true }
                .sharedSheet(isPresented: $isPresented) {
                    ColorEditorView(mode: .create(initial: RGBA(red: 0.9, green: 0.4, blue: 0.3)), onCancel: { isPresented = false }, onSave: { _ in isPresented = false })
                }
        }
    }
    return Preview().previewEnvironment()
}
#endif
private extension View {
    /// Interactive keyboard dismissal where the platform has a software keyboard to dismiss.
    @ContentBuilder
    func dismissingKeyboardOnScroll() -> some View {
        #if os(visionOS)
        self
        #else
        scrollDismissesKeyboard(.interactively)
        #endif
    }
}
#endif
