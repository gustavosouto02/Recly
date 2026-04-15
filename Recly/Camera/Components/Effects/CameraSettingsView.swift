//
//  CameraSettingsView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 15/04/26.
//

import Foundation
import SwiftUI
internal import AVFoundation

struct CameraSettingsView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var isPresented: Bool
    @FocusState private var isProjectFieldFocused: Bool
    private let resolutions = ["4K", "1080p", "720p"]
    private let frameRates = [24, 30, 60]
    
    var body: some View {
        NavigationStack {
            List {
                // 📝 PROJETO
                Section("Nome do clipe") {
                    TextField("ex: escritorio_", text: $cameraManager.projectName)
                        .focused($isProjectFieldFocused)
                        .font(.system(.body, design: .monospaced))
                        .submitLabel(.done)
                        .onChange(of: isProjectFieldFocused) {_, isFocused in
                            if !isFocused {
                                cameraManager.sanitizeProjectName()
                            }
                        }
                        .onSubmit {
                            cameraManager.sanitizeProjectName()
                        }
                }
                
                // 🎥 RESOLUÇÃO
                Section("Resolução") {
                    ForEach(resolutions, id: \.self) { res in
                        qualityRow(label: res, isSelected: currentResLabel == res) {
                            applyNewSettings(res: res, fps: nil)
                        }
                    }
                }
                
                // ⚡️ FRAME RATE
                Section("Frame Rate") {
                    ForEach(frameRates, id: \.self) { fps in
                        qualityRow(label: "\(fps)fps", isSelected: cameraManager.selectedQuality.fps == Int32(fps)) {
                            applyNewSettings(res: nil, fps: Int32(fps))
                        }
                    }
                }
                
                // 🛠 SOBRE / AVANÇADO
                Section("Sobre") {
                    // Toggle Estabilização
                    Toggle(isOn: $cameraManager.isCinematicEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Estabilização ativa")
                                    .fontWeight(.medium)
                                Text("Cinematic Extended (OIS + EIS)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(.green)
                        }
                    }
                    .tint(.green)
                    
                    // Tally Light (Flash Feedback)
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $cameraManager.isTallyLightEnabled) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tally Light")
                                        .fontWeight(.medium)
                                    Text("Lanterna pisca em brilho mínimo")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "lightbulb.led.fill")
                                    .foregroundStyle(.red)
                                    .symbolRenderingMode(.multicolor)
                            }
                        }
                        .tint(.red)
                        
                        if cameraManager.isTallyLightEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Intervalo:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(String(format: "%.1f", cameraManager.tallyInterval))s")
                                        .font(.caption.monospaced())
                                        .bold()
                                }
                                Slider(value: $cameraManager.tallyInterval, in: 1.0...5.0, step: 0.5)
                            }
                            .padding(.leading, 32)
                        }
                    }
                }
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isPresented = false
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.yellow)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    // MARK: - Helper Views
    
    private func qualityRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    
    // MARK: - Logic Mapping
    
    private var currentResLabel: String {
        let preset = cameraManager.selectedQuality.sessionPreset
        if preset == .hd4K3840x2160 { return "4K" }
        if preset == .hd1920x1080 { return "1080p" }
        return "720p"
    }
    
    private func applyNewSettings(res: String?, fps: Int32?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        let targetRes = res ?? currentResLabel
        let targetFPS = fps ?? cameraManager.selectedQuality.fps
        
        let newQuality: VideoQuality
        
        // Mapeamento exato de todas as combinações
        switch (targetRes, targetFPS) {
        case ("4K", 24): newQuality = .uhd4k24
        case ("4K", 30): newQuality = .uhd4k30
        case ("4K", 60): newQuality = .uhd4k60
        case ("1080p", 24): newQuality = .fullHD24
        case ("1080p", 30): newQuality = .fullHD30
        case ("1080p", 60): newQuality = .fullHD60
        case ("720p", 24): newQuality = .hd24
        case ("720p", 60): newQuality = .hd60
        default:           newQuality = .hd30
        }
        
        cameraManager.setVideoQuality(newQuality)
    }
}
