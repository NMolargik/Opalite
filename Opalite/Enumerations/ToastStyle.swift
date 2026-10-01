//
//  ToastStyle.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import SwiftUI

enum ToastStyle {
    case error
    case success
    case info

    var backgroundColor: Color {
        switch self {
        case .error:
            return .red
        case .success:
            return .green
        case .info:
            return .blue
        }
    }

    var iconName: String {
        switch self {
        case .error:
            return "xmark.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}
