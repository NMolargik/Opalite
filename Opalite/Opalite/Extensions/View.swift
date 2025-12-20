//
//  View-if.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func transitionSource(id: Int, namespace: Namespace.ID) -> some View {
        self.modifier(TransitionSourceModifier(id: id, namespace: namespace))
    }
}

private struct TransitionSourceModifier: ViewModifier {
    var id: Int
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .matchedTransitionSource(id: id, in: namespace) { src in
                src
                    .clipShape(.rect(cornerRadius: 10.0))
                    .shadow(radius: 12.0)
                    .background(.black)
            }
            #endif
    }
}
