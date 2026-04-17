//
//  ControlBarView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import SwiftUI

struct ControlBarView: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var showSettings = false
    @State private var showExposureControl = false
    
    var body: some View {
        
        ZStack {
            // 🔹 Conteúdo lateral (some quando grava)
            HStack {
                leftControls
                Spacer()
                rightControls
            }
            .opacity(cameraManager.isRecording ? 0 : 1)
            .scaleEffect(cameraManager.isRecording ? 0.8 : 1)
            .blur(radius: cameraManager.isRecording ? 10 : 0)
            .animation(.easeInOut(duration: 0.25), value: cameraManager.isRecording)
            
            // 🔴 Botão central (sempre visível)
            recordButton
                .zIndex(1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showExposureControl)
        .sheet(isPresented: $showSettings) {
            CameraSettingsView(cameraManager: cameraManager, isPresented: $showSettings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(backgroundView)
        .animation(.easeInOut(duration: 0.3), value: cameraManager.isRecording)
    }
    
    private var recordButton: some View {
        Button {
            cameraManager.isRecording
            ? cameraManager.stopRecording()
            : cameraManager.startRecording()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 72, height: 72)
                
                RoundedRectangle(cornerRadius: cameraManager.isRecording ? 6 : 35)
                    .fill(.red)
                    .frame(
                        width: cameraManager.isRecording ? 28 : 60,
                        height: cameraManager.isRecording ? 28 : 60
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cameraManager.isRecording)
            }
        }
    }
    
    private var leftControls: some View {
        HStack(spacing: 25) {
            Button {
                withAnimation {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
            }
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    cameraManager.showExposureControl.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "plusminus")
                    .font(.system(size: 22))
                    .foregroundStyle(cameraManager.showExposureControl ? .yellow : .white.opacity(0.8))
            }
        }
        .foregroundStyle(.white.opacity(0.8))
    }
    
    private var rightControls: some View {
        HStack(spacing: 25) {
            Button(action: {
                withAnimation(.easeInOut) {
                    cameraManager.switchCamera()
                }
            }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 20))
            }
        }
        .foregroundStyle(.white.opacity(0.8))
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 35, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 35)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .opacity(cameraManager.isRecording ? 0.7 : 1)
            .scaleEffect(cameraManager.isRecording ? 0.9 : 1)
    }
}

#Preview {
    ControlBarView(cameraManager: CameraManager())
}

