
//
//  ContentView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 08/04/26.
//

internal import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            CameraPreview(session: cameraManager.previewSession, cameraManager: cameraManager)
                .ignoresSafeArea()
            
            VStack {
                TopStatusBarView(cameraManager: cameraManager)
                Spacer()
                HStack {
                    VerticalLevelMeterView(level: cameraManager.audioLevel)
                    Spacer()
                }
                .padding(.leading, 30)
                Spacer()
                if cameraManager.showExposureControl {
                    exposureControlBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16)
                }
                
                ZoomControlView(cameraManager: cameraManager)
                ControlBarView(cameraManager: cameraManager)
                    .padding(.horizontal, 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            cameraManager.checkAuthorization()
        }
    }
    
    private var exposureControlBar: some View {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sun.max.fill").foregroundStyle(.yellow)
                    Text("Exposição").font(.caption.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Button("Reset") { cameraManager.setExposureBias(0.0) }
                        .font(.caption2).foregroundStyle(.secondary)
                }
                
                VStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(cameraManager.exposureBias) },
                        set: { cameraManager.setExposureBias(Float($0)) }
                    ), in: Double(cameraManager.exposureBiasRange.lowerBound)...Double(cameraManager.exposureBiasRange.upperBound))
                    .tint(.yellow)
                    
                    HStack {
                        Text(String(format: "%.1f", cameraManager.exposureBiasRange.lowerBound))
                        Spacer()
                        Text(String(format: "%.1f EV", cameraManager.exposureBias))
                            .foregroundStyle(.yellow)
                            .fontWeight(.bold)
                        Spacer()
                        Text(String(format: "+%.1f", cameraManager.exposureBiasRange.upperBound))
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        }
    
    
}

#Preview {
    ContentView()
}

