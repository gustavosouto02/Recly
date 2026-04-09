//
//  ZoomControlView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import SwiftUI

struct ZoomControlView: View {
    @ObservedObject var cameraManager: CameraManager
    @Namespace private var zoomNamespace
    
    private let zoomOptions = ["0.5", "1", "2"]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(zoomOptions, id: \.self) { option in
                zoomButton(for: option)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    @ViewBuilder
    private func zoomButton(for label: String) -> some View {
        let displayLabel = label + "x"
        let isSelected = currentBestLabel == displayLabel
        
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cameraManager.setZoomByLabel(displayLabel)
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 38, height: 38)
                        // matchedGeometryEffect faz o fundo cinza "viajar" entre os botões
                        .matchedGeometryEffect(id: "zoomCircle", in: zoomNamespace)
                }
                
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? .yellow : .white)
                    .frame(width: 38, height: 38)
            }
        }
    }
    
    private var currentBestLabel: String {
        let currentFactor = cameraManager.zoomFactor

        let distances = cameraManager.zoomMapping.map { (label: $0.key, distance: abs($0.value - currentFactor)) }
        
        return distances.min(by: { $0.distance < $1.distance })?.label ?? "1x"
    }
}

#Preview {
    ZoomControlView(cameraManager: CameraManager())
}
