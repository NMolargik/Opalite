//
//  CameraCaptureView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

#if canImport(UIKit) && !os(visionOS)
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView

        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#elseif os(visionOS)
import SwiftUI

/// Placeholder for visionOS where camera capture is unavailable.
struct CameraCaptureView: View {
    @Binding var selectedImage: UIImage?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Camera capture is not available on visionOS.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#elseif canImport(AppKit)
import AppKit

/// Placeholder for macOS where camera capture via UIImagePickerController is unavailable.
struct CameraCaptureView: View {
    @Binding var selectedImage: NSImage?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Camera capture is not available on macOS.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif
