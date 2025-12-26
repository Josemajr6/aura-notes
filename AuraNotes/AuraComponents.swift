//
//  AuraComponents.swift
//  AuraNotes
//
//  Created by José Manuel Jiménez Rodríguez on 22/12/25.
//

import SwiftUI

// Un botón que brilla y crece cuando pasas el ratón
struct AuraButton: View {
    var icon: String
    var action: () -> Void
    var helpText: String = ""
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isHovering ? .white : .gray)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovering ? 0.15 : 0.0))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isHovering ? 0.3 : 0), lineWidth: 1)
                )
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .shadow(color: .white.opacity(isHovering ? 0.5 : 0), radius: 5)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { hover in
            withAnimation(.snappy(duration: 0.2)) {
                isHovering = hover
            }
        }
    }
}

// Extensión para el efecto de "Temblor" cuando hay error
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}
