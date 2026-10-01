//
//  TVQuickAddHexSheet.swift
//  OpaliteFeatureTV
//
//  The one way to create on TV: type a hex code (and optionally a name) on the remote
//  keyboard, see it live, save.
//

#if os(tvOS)
import SwiftUI
import os
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVQuickAddHexSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ToastManager.self) private var toastManager
    @Environment(HexCopyModel.self) private var hexCopy

    @State private var hexText = "#"
    @State private var nameText = ""

    private var parsed: RGBA? { TVHexInput.parse(hexText) }

    var body: some View {
        VStack(spacing: 48) {
            Text("Add Color")
                .font(.title.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .center, spacing: 72) {
                preview

                VStack(alignment: .leading, spacing: Brand.Space.xl) {
                    VStack(alignment: .leading, spacing: Brand.Space.sm) {
                        Text("Hex Code")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        TextField("#FF5733", text: $hexText)
                            .textInputAutocapitalization(.characters)
                            .font(.title3.monospaced())
                            .onChange(of: hexText) { _, newValue in
                                let normalized = TVHexInput.normalized(newValue)
                                if normalized != newValue { hexText = normalized }
                            }
                            .accessibilityLabel(Text("Hex code"))
                            .accessibilityHint(Text("Three, six or eight hex digits, for example FF5733"))
                            .accessibilityIdentifier("hexField")
                    }

                    VStack(alignment: .leading, spacing: Brand.Space.sm) {
                        Text("Name (optional)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        TextField("Sunset Orange", text: $nameText)
                            .accessibilityLabel(Text("Color name"))
                            .accessibilityIdentifier("nameField")
                    }
                }
                .frame(width: 560)
            }

            HStack(spacing: Brand.Space.xxl) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .accessibilityIdentifier("cancel")
                Button("Save Color", systemImage: "checkmark") { save() }
                    .disabled(parsed == nil)
                    .accessibilityHint(Text(parsed == nil ? "Enter a valid hex code to save" : "Saves the color to your portfolio"))
                    .accessibilityIdentifier("save")
            }
        }
        .padding(TVLayout.gutter)
    }

    private var preview: some View {
        VStack(spacing: Brand.Space.lg) {
            Group {
                if let parsed {
                    TVSwatchFill(parsed, cornerRadius: Brand.Radius.sheet)
                } else {
                    RoundedRectangle(cornerRadius: Brand.Radius.sheet, style: .continuous)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "number")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: 320, height: 320)
            .animation(.easeInOut(duration: 0.2), value: parsed)

            Text(parsed.map { hexCopy.formatted($0.hexString) } ?? String(localized: "Enter a hex code"))
                .font(.title3.monospaced())
                .foregroundStyle(parsed == nil ? .tertiary : .secondary)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(parsed.map { String(localized: "Preview of \($0.hexString)") } ?? String(localized: "No color yet")))
    }

    private func save() {
        guard let rgba = parsed else { return }
        let name = TVHexInput.cleanName(nameText)
        guard let created = portfolio.createColor(rgba, name: name) else {
            // PortfolioModel already surfaced the failure as a toast.
            Log.portfolio.error("TV quick add failed for \(rgba.hexString, privacy: .public)")
            return
        }
        Log.portfolio.info("TV quick add created \(created.hexString, privacy: .public)")
        toastManager.showSuccess(String(localized: "Added \(hexCopy.formatted(created))"))
        dismiss()
    }
}

#if DEBUG
#Preview {
    TVQuickAddHexSheet()
        .previewEnvironment()
}
#endif
#endif
