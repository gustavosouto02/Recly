//
//  VerticalLevelMeterView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import SwiftUI

struct VerticalLevelMeterView: View {
    let level: Float // Recebe o valor de -160 a 0
        
        // Configurações visuais
        private let barWidth: CGFloat = 6
        private let barHeight: CGFloat = 120
        
        // Normaliza o valor para uma escala de 0.0 a 1.0
        private var normalizedLevel: CGFloat {
            let minLevel: Float = -60.0
            let cappedLevel = max(minLevel, min(0, level))
            return CGFloat((cappedLevel - minLevel) / abs(minLevel))
        }
        
        var body: some View {
            VStack(spacing: 4) {
                ZStack(alignment: .bottom) {
                    // Fundo da barra (Trilho)
                    Color.clear
                        .frame(width: barWidth, height: barHeight)
                    
                    // Barra de nível ativa
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.red, .yellow, .green],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: barHeight * normalizedLevel)
                        .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: normalizedLevel)
                }
                
                Text("MIC")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundStyle(.ultraThinMaterial.opacity(0.6))
                    .padding(.bottom, 2)
            }
            .padding(2)
            .frame(width: 20, height: 150) 
            .overlay(
                Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 5)
        }
}

#Preview {
    VerticalLevelMeterView(level: CameraManager().audioLevel)
}

