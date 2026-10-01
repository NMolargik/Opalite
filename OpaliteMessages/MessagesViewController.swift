//
//  MessagesViewController.swift
//  OpaliteMessages
//
//  The iMessage app: a grid of the user's colors (from the App Group snapshot); tapping
//  one sends a rendered swatch with its name and hex.
//

import Messages
import SwiftUI
import UIKit
import OpaliteCore
import OpaliteDesignSystem
import os

final class MessagesViewController: MSMessagesAppViewController {
    private var host: UIHostingController<MessageColorPicker>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: makePicker())
        self.host = host
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    override func willBecomeActive(with conversation: MSConversation) {
        host?.rootView = makePicker()
    }

    private func makePicker() -> MessageColorPicker {
        MessageColorPicker(
            colors: WidgetColorStorage().loadColors(),
            onSelect: { [weak self] in self?.send($0) },
            onExpand: { [weak self] in self?.requestPresentationStyle(.expanded) }
        )
    }

    private func send(_ color: WidgetColor) {
        guard let conversation = activeConversation else { return }
        guard let image = ImageRendering.uiImage(MessageSwatchImage(color: color), size: CGSize(width: 300, height: 300), opaque: true) else { return }
        let layout = MSMessageTemplateLayout()
        layout.image = image
        layout.caption = color.displayName
        layout.subcaption = color.hexString
        let message = MSMessage()
        message.layout = layout
        message.url = DeepLink.color(color.id).url
        conversation.insert(message) { error in
            if let error { Log.sharing.error("Message insert failed: \(error.localizedDescription)") }
        }
        dismiss()
    }
}

struct MessageColorPicker: View {
    let colors: [WidgetColor]
    let onSelect: (WidgetColor) -> Void
    let onExpand: () -> Void

    var body: some View {
        if colors.isEmpty {
            ContentUnavailableView("No Colors", systemImage: "paintpalette", description: Text("Open Opalite to create colors."))
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 110), spacing: Brand.Space.sm)], spacing: Brand.Space.sm) {
                    ForEach(colors) { color in
                        Button {
                            onSelect(color)
                        } label: {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                                    .fill(color.swiftUIColor)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                                Text(color.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(color.displayName), \(color.hexString)")
                        .accessibilityHint("Sends this color")
                    }
                }
                .padding()
            }
        }
    }
}

struct MessageSwatchImage: View {
    let color: WidgetColor

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            color.swiftUIColor
            HexBadge(color.displayName, onDark: !color.prefersDarkText, font: .headline)
                .padding(12)
        }
    }
}
