//
//  WhiteBalancePresetBarView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 14/04/26.
//

import Foundation
import SwiftUI

struct WhiteBalancePreset: Identifiable {
    let id: Float
    let label: String
    let icon: String
    let value: Float
}

struct WhiteBalancePresetBarView: View {
    @ObservedObject var cameraManager: CameraManager
    
    private let presets: [WhiteBalancePreset] = [
            .init(id: 0, label: "Auto", icon: "sun.max.trianglebadge.exclamationmark", value: 0),
            .init(id: 2800, label: "2800K", icon: "lightbulb.fill", value: 2800),    // Incandescente
            .init(id: 4000, label: "4000K", icon: "lamp.desk.fill", value: 4000),   // Fluorescente
            .init(id: 5600, label: "5600K", icon: "sun.max.fill", value: 5600),     // Luz do Dia
            .init(id: 6500, label: "6500K", icon: "cloud.fill", value: 6500),       // Nublado
            .init(id: 7500, label: "7500K", icon: "cloud.sun.fill", value: 7500)    // Sombra
        ]
    
    var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets) { preset in
                        presetItem(preset)
                    }
                }
                .padding(.horizontal, 15)
            }
            .frame(height: 80)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    
    // MARK: - Item

    private func presetItem(_ preset: WhiteBalancePreset) -> some View {
        let isSelected = cameraManager.whiteBalance == preset.value
        
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cameraManager.setWhiteBalance(preset.value)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 18))
                
                Text(preset.label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .frame(width: 65, height: 60)
            .background(isSelected ? Color.yellow.opacity(0.2) : Color.white.opacity(0.05))
            .foregroundStyle(isSelected ? .yellow : .white.opacity(0.7))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
    }
    // MARK: - Helpers
    
    private func label(for value: Float) -> String {
        if value == 0 { return "Auto" }
        return "\(Int(value))K"
    }
    
    private func isSelectedPreset(_ value: Float) -> Bool {
        if value == 0 { return false } // auto não fixa
        
        return abs(cameraManager.whiteBalance - value) < 200
    }
    
    private func setAutoWhiteBalance() {
        cameraManager.setWhiteBalance(5600) // fallback neutro
        // futuramente: implementar auto real no device
    }
}
