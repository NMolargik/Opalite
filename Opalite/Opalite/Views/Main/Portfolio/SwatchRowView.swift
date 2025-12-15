//
//  SwatchRowView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SwatchRowView: View {
    let colors: [OpaliteColor]
    let swatchWidth: CGFloat
    let swatchHeight: CGFloat
    var onReceiveSwatch: (([NSItemProvider]) -> Bool)? = nil
    var showBadge: Bool = false
    var menuContent: ((OpaliteColor) -> AnyView)? = nil
    var contextMenuContent: ((OpaliteColor) -> AnyView)? = nil
    
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        Group {
            if (colors.isEmpty) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.down.right")
                        .bold()
                    
                    Button {
                        // TODO: show color creator
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.square.dashed")
                                .font(.title2)
                            
                            Text("Add New or Existing Colors")
                        }
                        .bold()
                        .foregroundStyle(.inverseTheme)
                        .padding(.horizontal, 10)
                        .frame(height: 20)
                        .padding(8)
                        .multilineTextAlignment(.center)
                        .glassEffect(.clear.tint(.blue).interactive())
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .hoverEffect(.lift)
                    }
                }
                .padding(.leading, 35)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            NavigationLink {
                                ColorDetailView(color: color)
                            } label: {
                                SwatchView(
                                    fill: [color],
                                    width: swatchWidth,
                                    height: swatchHeight,
                                    badgeText: showBadge ? (color.name ?? color.hexString) : nil,
                                    menu: menuContent?(color),
                                    contextMenu: contextMenuContent?(color)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 5)
                    }
                    .padding(.leading)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onDrop(of: [UTType.opaliteColorID, .image, .png, .jpeg], isTargeted: $isDropTargeted) { providers in
            return onReceiveSwatch?(providers) ?? false
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colors.isEmpty ? .inverseTheme : .blue, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .opacity(isDropTargeted ? 1 : 0)
                .padding(.leading, colors.isEmpty ? 65 : 10)
                .padding(.trailing, colors.isEmpty ? 0 : -20) // bleed past trailing edge
        )
    }
}

#Preview {
    VStack {
        SwatchRowView(
            colors: [OpaliteColor.sample, OpaliteColor.sample2],
            swatchWidth: 75,
            swatchHeight: 75
        )
        
        SwatchRowView(
            colors: [OpaliteColor.sample, OpaliteColor.sample2],
            swatchWidth: 150,
            swatchHeight: 150,
            showBadge: true,
            menuContent: { _ in
                AnyView(
                    Group {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )
            }
        )
        
        SwatchRowView(
            colors: [OpaliteColor.sample, OpaliteColor.sample2],
            swatchWidth: 200,
            swatchHeight: 200,
            showBadge: true,
            menuContent: { _ in
                AnyView(
                    Group {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )
            }
        )
    }
}
