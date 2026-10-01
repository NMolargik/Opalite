//
//  SheetChrome.swift
//  OpaliteFeatureSharing
//
//  The small pieces every sharing sheet is built from: the presentation treatment
//  (detents on compact, form sizing on regular), the bottom action bar that holds the one
//  primary action, the status callout, and the format descriptor the export rows read.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import UniformTypeIdentifiers
import OpaliteCore
import OpaliteDesignSystem

// MARK: - Presentation

extension View {
    /// Compact: the given detents with a drag indicator when there's more than one.
    /// Regular (iPad, Mac, visionOS): a form-sized sheet.
    func sharingSheet(detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(detents.count > 1 ? .visible : .automatic)
            .presentationSizing(.form)
    }
}

// MARK: - Action bar

/// The bottom bar of a sheet: an optional status line and the primary (and secondary)
/// action, sitting on a bar background so content scrolls underneath.
struct ActionBar<Content: View>: View {
    @ContentBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: Brand.Space.sm) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.md)
        .background(.bar)
    }
}

// MARK: - Status callout

/// An icon-led explanation (why an action is unavailable, what an import will do).
struct StatusCallout: View {
    let title: String
    let message: String
    let systemImage: String
    var tint: Color = .opalitePurple

    var body: some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Outcome row

/// A line in an import summary: tinted glyph plus text.
struct OutcomeRow: View {
    let outcome: ImportOutcome

    private var tint: Color {
        switch outcome.kind {
        case .add: .green
        case .update: .blue
        case .move: .orange
        case .skip: .yellow
        }
    }

    var body: some View {
        Label {
            Text(outcome.text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: outcome.systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
        .labelStyle(.alignedIcon)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tag chips

/// The tags a palette will carry, wrapped onto rows.
struct TagChips: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: Brand.Space.sm) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, Brand.Space.sm)
                    .padding(.vertical, Brand.Space.xs)
                    .background(Capsule(style: .continuous).fill(Color.opalitePurple.opacity(0.18)))
                    .accessibilityLabel(Text("Tag \(tag)"))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Export format descriptor

/// Everything an export row needs from a format, so the color and palette sheets share
/// one implementation.
protocol PresentableExportFormat: ExportFormat {
    var displayName: String { get }
    var formatDescription: String { get }
    var tint: Color { get }
    var contentType: UTType { get }
}

extension ColorExportFormat: PresentableExportFormat {
    var contentType: UTType { ExportContentType.utType(for: self) }
}

extension PaletteExportFormat: PresentableExportFormat {
    var contentType: UTType { ExportContentType.utType(for: self) }
}
#endif
