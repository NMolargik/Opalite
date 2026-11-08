//
//  SettingsToggleStyle.swift
//  OpaliteDesignSystem
//
//  A settings row with the label on the leading edge and the control on the trailing
//  edge. On Mac Catalyst's Mac idiom a plain `Toggle` in a list draws a checkbox in front
//  of its label; this keeps every settings toggle in the iOS shape (label, then control)
//  on every platform, while the control itself stays native (a switch on iOS, a checkbox
//  on Mac).
//

import SwiftUI

public struct SettingsToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Brand.Space.md) {
            configuration.label
            Spacer(minLength: Brand.Space.sm)
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .labelsHidden()
                .fixedSize()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

public extension ToggleStyle where Self == SettingsToggleStyle {
    /// Label on the leading edge, native control on the trailing edge.
    static var settingsRow: SettingsToggleStyle { SettingsToggleStyle() }
}
