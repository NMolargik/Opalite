//
//  PhotoSamplerSheet.swift
//  OpaliteFeatureColorEditor
//
//  The standalone "Sample Photo" sheet (quick action, share extension, drag-in): pick or
//  drop an image, tap to sample, stage as many colors as you like, then add them all.
//  Each staged color is handed back through `onSample`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import UIKit

public struct PhotoSamplerSheet: View {
    private let initialImage: PlatformImage?
    private let onSample: (RGBA) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var stagedChip: CGFloat = 56

    @State private var image: UIImage?
    @State private var cgImage: CGImage?
    @State private var sampledPoint: CGPoint?
    @State private var sampledColor: RGBA?
    @State private var staged: [Staged] = []
    @State private var isDropTargeted = false

    private struct Staged: Identifiable, Hashable {
        let id = UUID()
        let rgba: RGBA
    }

    public init(image: PlatformImage? = nil, onSample: @escaping (RGBA) -> Void) {
        self.initialImage = image
        self.onSample = onSample
    }

    private var colorsToAdd: [RGBA] {
        staged.isEmpty ? sampledColor.map { [$0] } ?? [] : staged.map(\.rgba)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.lg) {
                    ImageSourceBar(onImage: setImage, onScreenSample: stage)

                    if let image {
                        SamplingImageView(
                            image: image,
                            cgImage: cgImage,
                            sampledPoint: sampledPoint,
                            sampledColor: sampledColor,
                            onSample: { rgba, point in
                                sampledColor = rgba
                                sampledPoint = point
                            },
                            onEnded: { Haptics.lightImpact() }
                        )
                        .frame(maxHeight: 440)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))

                        if let sampledColor {
                            sampledCard(sampledColor)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            Label("Tap or drag on the image to sample a color", systemImage: "hand.tap")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ImageDropPlaceholder(isTargeted: isDropTargeted)
                    }

                    if !staged.isEmpty {
                        stagedSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(Brand.Space.lg)
                .frame(maxWidth: Brand.detailMaxWidth)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: image == nil)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: sampledColor == nil)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: staged)
            }
            .softScrollEdgesIfAvailable()
            .background(groupedBackground.ignoresSafeArea())
            .navigationTitle(Text("Sample Photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                    .accessibilityIdentifier("photoSampler.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: addAll) {
                        Text(addTitle)
                            .fontWeight(.semibold)
                            .contentTransition(.numericText())
                    }
                    .disabled(colorsToAdd.isEmpty)
                    .accessibilityIdentifier("photoSampler.add")
                }
            }
            .dropDestination(for: Data.self) { items, _ in
                guard let data = items.first, let dropped = UIImage(data: data) else { return false }
                setImage(dropped)
                return true
            } isTargeted: { isDropTargeted = $0 }
        }
        .onAppear {
            if image == nil, let initialImage { setImage(initialImage) }
        }
    }

    private var addTitle: String {
        let count = colorsToAdd.count
        return count > 1 ? String(localized: "Add \(count)") : String(localized: "Add")
    }

    // MARK: - Sampled color

    private func sampledCard(_ rgba: RGBA) -> some View {
        HStack(spacing: Brand.Space.lg) {
            RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous)
                .fill(rgba.color)
                .frame(width: 64, height: 64)
                .overlay(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous).strokeBorder(.quaternary))
            VStack(alignment: .leading, spacing: 4) {
                Text(rgba.hexString)
                    .font(.title3.monospaced().weight(.semibold))
                    .contentTransition(.numericText())
                Text(rgba.rgbString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(ColorClassifier.description(of: rgba).capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                stage(rgba)
            } label: {
                Label("Stage", systemImage: "plus")
            }
            .glassActionButton(tint: .opalitePurple, prominent: true)
            .accessibilityLabel(Text("Stage \(rgba.hexString)"))
            .accessibilityHint(Text("Adds this color to the list to import"))
            .accessibilityIdentifier("photoSampler.stage")
        }
        .padding(Brand.Space.lg)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Staged

    private var stagedSection: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            HStack {
                Label {
                    Text("Staged")
                } icon: {
                    Image(systemName: "tray.full")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.opalitePurple)
                }
                .font(.headline)
                Text("\(staged.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
                Button(role: .destructive) {
                    Haptics.selection()
                    staged.removeAll()
                } label: {
                    Text("Clear")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Clear staged colors"))
            }
            .accessibilityElement(children: .combine)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Brand.Space.md) {
                    ForEach(staged) { item in
                        VStack(spacing: Brand.Space.xs) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                                    .fill(item.rgba.color)
                                    .frame(width: stagedChip, height: stagedChip)
                                    .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                                Button {
                                    Haptics.selection()
                                    staged.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .red)
                                        .shadow(radius: 1)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 7, y: -7)
                                .accessibilityLabel(Text("Remove \(item.rgba.hexString)"))
                            }
                            Text(item.rgba.hexString)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, Brand.Space.sm)
                .padding(.horizontal, 2)
            }
        }
        .padding(Brand.Space.lg)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }

    // MARK: - Actions

    private func setImage(_ new: UIImage) {
        image = new
        cgImage = new.sampleableCGImage()
        sampledPoint = nil
        sampledColor = nil
    }

    private func stage(_ rgba: RGBA) {
        Haptics.lightImpact()
        staged.append(Staged(rgba: rgba))
        sampledColor = nil
        sampledPoint = nil
    }

    private func addAll() {
        let colors = colorsToAdd
        guard !colors.isEmpty else { return }
        Haptics.success()
        for rgba in colors { onSample(rgba) }
        dismiss()
    }
}

#if DEBUG
#Preview("Photo sampler") {
    PhotoSamplerSheet { _ in }
}

#Preview("With image") {
    let image = ImageRendering.uiImage(LinearGradient.opalite, size: CGSize(width: 600, height: 400))
    return PhotoSamplerSheet(image: image) { _ in }
}
#endif
#endif
