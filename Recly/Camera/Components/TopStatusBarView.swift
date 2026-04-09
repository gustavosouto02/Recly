//
//  TopStatusBarView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import SwiftUI

struct TopStatusBarView: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var isBeaconAnimating = false
    
    private var formattedDuration: String {
        let duration = Int(cameraManager.recordingDuration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        HStack {
            // LADO ESQUERDO - qual microfone esta sendo utilizado (built in, algum outro)
            Text("Microfone")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(.ultraThinMaterial)
            
            
            Spacer()
            
            // LADO DIREITO: Timer
            HStack(spacing: 6) {
                if cameraManager.isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(isBeaconAnimating ? 1.0 : 0.4)
                    
                    Text(formattedDuration)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(.ultraThinMaterial)
                        .opacity(cameraManager.isRecording ? 1 : 0) // Só aparece se estiver gravando
                }
            }
            
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBeaconAnimating.toggle()
            }
        }
    }
}

#Preview {
    TopStatusBarView(cameraManager: CameraManager())
}
