//
//  SectionCardView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct SectionCard<Content: View, TrailingContent: View>: View {
    let title: String
    let systemImage: String
    let isCollapsible: Bool
    @ViewBuilder var content: Content
    @ViewBuilder var trailing: TrailingContent

    @State private var isExpanded: Bool = true

    init(
        title: String,
        systemImage: String,
        isCollapsible: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isCollapsible = isCollapsible
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .bold()
                Spacer(minLength: 0)
                trailing
                if isCollapsible {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isCollapsible else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                content
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SectionCardBackground())
        .clipped()
    }
}

// MARK: - Glass Background

private struct SectionCardBackground: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    func body(content: Content) -> some View {
        #if os(visionOS)
        content
            .background(shape.fill(.ultraThinMaterial))
            .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
        #else
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
        }
        #endif
    }
}

extension SectionCard where TrailingContent == EmptyView {
    init(
        title: String,
        systemImage: String,
        isCollapsible: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isCollapsible = isCollapsible
        self.content = content()
        self.trailing = EmptyView()
    }
}

#Preview("Section Card") {
    SectionCard(title: "Details", systemImage: "info.circle") {
        VStack(alignment: .leading, spacing: 8) {
            Text("This is example content inside the card.")
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
                Text("Status: Active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Primary Action") {}
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
    }
    .padding()
}

#Preview("Section Card – Dark") {
    SectionCard(title: "Details", systemImage: "info.circle") {
        VStack(alignment: .leading, spacing: 8) {
            Text("This is example content inside the card.")
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
                Text("Status: Active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Primary Action") {}
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
    }
    .padding()
    .preferredColorScheme(.dark)
}
