//
//  MessagesViewController.swift
//  OpaliteMessages
//
//  Created by Nick Molargik on 1/18/26.
//

import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    private var hostingController: UIHostingController<ColorPickerView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupColorPicker()
    }

    private func setupColorPicker() {
        let colorPickerView = ColorPickerView(
            onColorSelected: { [weak self] color in
                self?.sendColor(color)
            },
            onRequestExpand: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )

        let hostingController = UIHostingController(rootView: colorPickerView)
        self.hostingController = hostingController

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    private func sendColor(_ color: WidgetColor) {
        guard let conversation = activeConversation else { return }

        // Render the color swatch as an image
        let swatchSize = CGSize(width: 300, height: 300)
        let renderer = ImageRenderer(content: ColorSwatchImage(color: color, size: swatchSize))
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else { return }

        // Create the message layout
        let layout = MSMessageTemplateLayout()
        layout.image = uiImage
        layout.caption = color.displayName
        layout.subcaption = color.hexString

        // Create and send the message
        let message = MSMessage()
        message.layout = layout

        conversation.insert(message) { error in
            if let error = error {
                print("Failed to send color message: \(error.localizedDescription)")
            }
        }

        // Dismiss to compact after sending
        dismiss()
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        // Refresh colors when becoming active
        hostingController?.rootView = ColorPickerView(
            onColorSelected: { [weak self] color in
                self?.sendColor(color)
            },
            onRequestExpand: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Update the view for the new presentation style
    }
}

// MARK: - SwiftUI Color Picker View

struct ColorPickerView: View {
    let onColorSelected: (WidgetColor) -> Void
    let onRequestExpand: () -> Void

    @State private var colors: [WidgetColor] = []

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 100), spacing: 8)
    ]

    var body: some View {
        Group {
            if colors.isEmpty {
                emptyState
            } else {
                colorGrid
            }
        }
        .onAppear {
            colors = WidgetColorStorage.loadColors()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintpalette")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Colors")
                .font(.headline)

            Text("Open Opalite to create colors")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var colorGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(colors) { color in
                    ColorCell(color: color)
                        .onTapGesture {
                            onColorSelected(color)
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Color Cell

struct ColorCell: View {
    let color: WidgetColor

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.swiftUIColor)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                )

            Text(color.displayName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Color Swatch Image for Sending

struct ColorSwatchImage: View {
    let color: WidgetColor
    let size: CGSize

    var body: some View {
        ZStack {
            // Color fill
            color.swiftUIColor

            // Name label in bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(color.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color.idealTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(color.idealTextColor == .white ? .black.opacity(0.3) : .white.opacity(0.3))
                        )
                        .padding(12)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Preview

#Preview {
    ColorPickerView(
        onColorSelected: { _ in },
        onRequestExpand: { }
    )
}
