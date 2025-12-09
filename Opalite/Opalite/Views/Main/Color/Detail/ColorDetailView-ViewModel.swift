//
//  ColorDetailView-ViewModel.swift
//  Opalite
//
//  Created by Nick Molargik on 12/9/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension ColorDetailView {
    @Observable
    class ViewModel {
        // Model
        var color: OpaliteColor
        
        // UI State
        var isDetailsExpanded: Bool = false
        var isShowingPalettePicker: Bool = false
        var pendingColorForPalette: OpaliteColor?
        var didCopyHex: Bool = false
        var isEditingName: Bool = false
        var draftName: String = ""
        var isEditingColor: Bool = false
        
        init(color: OpaliteColor) {
            self.color = color
        }
        
        // MARK: - Derived Properties
        var displayTitle: String {
            if let name = color.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
            return color.hexString
        }
        
        var swatchColor: Color { color.swiftUIColor }
        
        var createdAtText: String {
            color.createdAt.formatted(date: .abbreviated, time: .shortened)
        }
        
        var updatedAtText: String {
            color.updatedAt.formatted(date: .abbreviated, time: .shortened)
        }
        
        var createdByText: String { color.createdByDisplayName ?? "—" }
        var createdOnDeviceText: String { color.createdOnDeviceName ?? "—" }
        var updatedOnDeviceText: String { color.updatedOnDeviceName ?? "—" }
        
        // MARK: - Actions
        func saveOtherColor(_ color: OpaliteColor, using manager: ColorManager) {
            do {
                try manager.addColor(color)
            } catch {
                print("Failed to add color: \(error)")
            }
        }
        
        func saveColorToPalette(color: OpaliteColor) {
            pendingColorForPalette = color
            isShowingPalettePicker = true
        }
        
        func savePendingColor(to palette: OpalitePalette, using manager: ColorManager) {
            guard let pendingColorForPalette else { return }
            do {
                try manager.addColor(pendingColorForPalette, to: palette)
                isShowingPalettePicker = false
                self.pendingColorForPalette = nil
                Task { await manager.refresh() }
            } catch {
                print("Failed to save color to palette: \(error)")
            }
        }
        
        func createPaletteAndSavePendingColor(named name: String, using manager: ColorManager) {
            do {
                let newPalette = try manager.addPalette(name: name)
                try manager.addColor(pendingColorForPalette ?? OpaliteColor.sample, to: newPalette)
                isShowingPalettePicker = false
                pendingColorForPalette = nil
                Task { await manager.refresh() }
            } catch {
                print("Failed to create/select palette: \(error)")
            }
        }
        
        func cancelPaletteSelection() {
            isShowingPalettePicker = false
            pendingColorForPalette = nil
        }
        
        func beginEditName() {
            draftName = color.name ?? ""
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                isEditingName = true
            }
        }

        func commitEditName(using manager: ColorManager) {
            let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                try manager.update(color) { c in
                    c.name = trimmed.isEmpty ? nil : trimmed
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditingName = false
                }
                Task { await manager.refresh() }
            } catch {
                print("Failed to update color name: \(error)")
            }
        }
        
        func copyHex() {
            let hex = color.hexString
#if os(iOS) || os(visionOS)
            UIPasteboard.general.string = hex
#elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
#endif
            
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopyHex = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.didCopyHex = false
                }
            }
        }
        
        func approveEdit(with editedColor: OpaliteColor, using manager: ColorManager) {
            withAnimation(.easeInOut) {
                do {
                    try manager.update(self.color) { c in
                        c.name = editedColor.name
                        c.notes = editedColor.notes
                        c.isPinned = editedColor.isPinned
                        c.red = editedColor.red
                        c.green = editedColor.green
                        c.blue = editedColor.blue
                        c.alpha = editedColor.alpha
                    }
                    isEditingColor = false
                } catch {
                    print("Failed to save edited color: \(error)")
                }
            }
            Task { await manager.refresh() }
        }
        
        func shareColorAsImage() {
#if os(iOS) || os(visionOS)
            // Build a 1024x1024 view representing the color
            let nameText = color.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hexText = color.hexString

            let bestTextColor = color.idealTextColor()
            let textColor = bestTextColor.swiftUIColor

            let shareView = ZStack {
                color.swiftUIColor
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        if let nameText, !nameText.isEmpty {
                            Text(nameText)
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.5)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(textColor)
                        }
                        Spacer()
                    }

                    Spacer()

                    HStack {
                        Spacer()
                        Text(hexText)
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(textColor)
                    }
                }
                .padding(64)
            }
            .frame(width: 1024, height: 1024)

            let renderer = ImageRenderer(content: shareView)

            // Match screen scale for crisp output
            renderer.scale = UIScreen.main.scale

            guard let image = renderer.uiImage else {
                print("Failed to render color image for sharing")
                return
            }

            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
               let root = scene.keyWindow?.rootViewController {
                root.present(activityVC, animated: true)
            } else {
                print("Unable to find a suitable window to present share sheet")
            }
#else
            // Non-iOS platforms can be implemented using NSImage + NSSharingServicePicker, etc.
            print("Share as image is currently only implemented on iOS/visionOS")
#endif
        }
    }
}

#if canImport(UIKit)
extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first { $0.isKeyWindow }
    }
}
#endif
