//
//  ControlBarView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import SwiftUI

struct ControlBarView: View {
    @ObservedObject var cameraManager: CameraManager
    
    var body: some View {
            HStack(alignment: .center, spacing: 0) {
                
                // Lado Esquerdo: Configurações e Efeitos
                HStack(spacing: 25) {
                    Button(action: { /* Ação Config */ }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                    }
                    
                    Button(action: { /* Ação Efeitos/Luz */ }) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 22))
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white.opacity(0.8))
                
                // Centro: Botão de Gravação (Destaque)
                Button {
                    cameraManager.isRecording ? cameraManager.stopRecording() : cameraManager.startRecording()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)
                            .frame(width: 72, height: 72)
                        
                        RoundedRectangle(cornerRadius: cameraManager.isRecording ? 6 : 35)
                            .fill(.red)
                            .frame(width: cameraManager.isRecording ? 28 : 60,
                                   height: cameraManager.isRecording ? 28 : 60)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cameraManager.isRecording)
                    }
                }
                .padding(.horizontal, 10)
                
                // Lado Direito: Botão Útil e Flip
                HStack(spacing: 25) {
                    Button(action: { /* Botão extra futuro */ }) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut) {
                            cameraManager.switchCamera()
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 20))
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial) // Efeito de vidro da Apple
            .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 35, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
}

#Preview {
    ControlBarView(cameraManager: CameraManager())
}
