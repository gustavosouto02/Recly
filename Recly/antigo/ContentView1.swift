////
////  ContentView.swift
////  Recly
////
////  Created by Gustavo Souto Pereira on 08/04/26.
////
//
//import SwiftUI
//import AVFoundation
//import Combine
//
//// MARK: - Design Tokens
//
//private enum RT {
//    static let recRed     = Color(red: 0.95, green: 0.18, blue: 0.18)
//    static let gold       = Color(red: 1.00, green: 0.80, blue: 0.20)
//    static let dimWhite   = Color.white.opacity(0.82)
//    static let cornerDock = CGFloat(22)
//    static let cornerPill = CGFloat(10)
//}
//
//// MARK: - Camera Preview
//
//struct CameraPreviewLayer: UIViewRepresentable {
//    let session: AVCaptureSession
//
//    func makeUIView(context: Context) -> PreviewView {
//        let v = PreviewView()
//        v.previewLayer.session = session
//        v.previewLayer.videoGravity = .resizeAspectFill
//        return v
//    }
//    func updateUIView(_ uiView: PreviewView, context: Context) {}
//
//    final class PreviewView: UIView {
//        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
//        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
//    }
//}
//
//
//// MARK: - Top Monitoring Bar
//
//struct TopMonitoringBar: View {
//    let isRecording: Bool
//    let duration: TimeInterval
//    let micLabel: String
//    @State private var recDot = true
//
//    private var formattedDuration: String {
//        let h = Int(duration) / 3600
//        let m = (Int(duration) % 3600) / 60
//        let s = Int(duration) % 60
//        return h > 0
//            ? String(format: "%02d:%02d:%02d", h, m, s)
//            : String(format: "%02d:%02d", m, s)
//    }
//
//    var body: some View {
//        HStack(alignment: .center) {
//
//            // REC Badge
//            HStack(spacing: 5) {
//                Circle()
//                    .fill(RT.recRed)
//                    .frame(width: 7, height: 7)
//                    .opacity(isRecording ? (recDot ? 1 : 0.15) : 0.3)
//                    .animation(isRecording ? .easeInOut(duration: 0.55).repeatForever() : .default,
//                               value: recDot)
//                    .onAppear { recDot.toggle() }
//                    .onChange(of: isRecording) { _, rec in
//                        recDot = true
//                        if rec { withAnimation(.easeInOut(duration: 0.55).repeatForever()) { recDot.toggle() } }
//                    }
//                Text("REC")
//                    .font(.system(size: 11, weight: .black, design: .monospaced))
//                    .foregroundStyle(isRecording ? RT.recRed : Color.white.opacity(0.35))
//            }
//            .padding(.horizontal, 10)
//            .padding(.vertical, 5)
//            .background(.ultraThinMaterial, in: Capsule())
//            .overlay(Capsule().stroke(RT.recRed.opacity(isRecording ? 0.55 : 0.2), lineWidth: 1))
//
//            Spacer()
//
//            // Active Mic
//            HStack(spacing: 5) {
//                Image(systemName: "mic.fill")
//                    .font(.system(size: 10))
//                    .foregroundStyle(RT.dimWhite)
//                Text(micLabel)
//                    .font(.system(size: 11, weight: .medium, design: .monospaced))
//                    .foregroundStyle(RT.dimWhite)
//            }
//            .padding(.horizontal, 10)
//            .padding(.vertical, 5)
//            .background(.ultraThinMaterial, in: Capsule())
//            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
//
//            Spacer()
//
//            // Timer
//            Text(formattedDuration)
//                .font(.system(size: 14, weight: .semibold, design: .monospaced))
//                .foregroundStyle(isRecording ? .white : Color.white.opacity(0.4))
//                .padding(.horizontal, 12)
//                .padding(.vertical, 5)
//                .background(.ultraThinMaterial, in: Capsule())
//                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
//        }
//        .padding(.horizontal, 16)
//    }
//}
//
//// MARK: - LevelMeterView (Vertical VU)
//
//struct LevelMeterView: View {
//    let level: Float
//    private let barHeight: CGFloat = 80 // Altura máxima da barra
//    
//    private var normalized: CGFloat {
//        CGFloat((max(-60, min(0, level)) + 60) / 60)
//    }
//
//    var body: some View {
//        VStack(spacing: 4) {
//            // Container da barra sem fundo visível
//            ZStack(alignment: .bottom) {
//                // Espaçador invisível para manter o frame fixo e evitar que o MIC suba/desça
//                Color.clear
//                    .frame(width: 4, height: barHeight)
//                
//                // Barra de cor ativa
//                Capsule()
//                    .fill(
//                        LinearGradient(
//                            colors: [RT.recRed, .yellow, Color(red: 0.22, green: 0.85, blue: 0.40)],
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                    )
//                    // A altura é o multiplicador do nível normalizado
//                    .frame(width: 4, height: barHeight * normalized)
//            }
//            // Animação rápida para refletir o pico do áudio em tempo real
//            .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: normalized)
//            
//            Text("MIC")
//                .font(.system(size: 6, weight: .black, design: .monospaced))
//                .foregroundStyle(.white.opacity(0.4))
//        }
//        // Background geral do componente (opcional, remova se quiser apenas a barra "solta")
//        .padding(.vertical, 6)
//        .padding(.horizontal, 4)
//        .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
//    }
//}
//
//// MARK: - Waveform Monitor
//
//struct WaveformView: View {
//    let level: Float
//    @State private var bars: [Float] = Array(repeating: 0.08, count: 18)
//
//    var body: some View {
//        HStack(spacing: 2.5) {
//            ForEach(0..<bars.count, id: \.self) { i in
//                RoundedRectangle(cornerRadius: 1.5)
//                    .fill(Color.white.opacity(0.65))
//                    .frame(width: 3, height: CGFloat(max(0.06, bars[i])) * 28)
//            }
//        }
//        .frame(height: 28)
//        .onReceive(Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()) { _ in
//            let norm = Float(max(0, min(1, (level + 60) / 60)))
//            let jitter = Float.random(in: 0...0.18)
//            bars.removeFirst()
//            bars.append(min(1, norm + jitter))
//        }
//    }
//}
//
//// MARK: - Lens Selector
//
//struct LensSelectorView: View {
//    @ObservedObject var camera: CameraManager
// 
//    private var lenses: [String] {
//        // Esconde "0.5x" se não houver lente Ultra-Wide física (ex: câmera frontal, iPhone antigo)
//        if ((camera.zoomMap?.ultraWide) != nil) {
//            return ["0.5x", "1x", "2x"]
//        } else {
//            return ["1x", "2x"]
//        }
//    }
// 
//    /// Label do botão activo, calculado a partir do factor de zoom actual.
//    /// Actualizações do `currentZoomFactor` (pinch, botões, flip) propagam-se automaticamente.
//    private var activeLens: String {
//            // Se o mapa ainda não carregou, assume 1x
//            guard let map = camera.zoomMap else { return "1x" }
//            return map.activeLabel(for: camera.currentZoomFactor)
//        }
// 
//    var body: some View {
//        HStack(spacing: 0) {
//                    ForEach(lenses, id: \.self) { lens in
//                        Button {
//                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
//                                camera.switchPhysicalLens(to: lens)
//                        } label: {
//                            Text(lens)
//                                .font(.system(size: 12, weight: activeLens == lens ? .black : .regular, design: .monospaced))
//                                .foregroundStyle(activeLens == lens ? .black : Color.white.opacity(0.8))
//                                .padding(.horizontal, 11)
//                                .padding(.vertical, 6)
//                                .background(activeLens == lens ? Color.white : Color.clear, in: Capsule())
//                        }
//                    }
//                }
//        .padding(3)
//        .background(.ultraThinMaterial, in: Capsule())
//        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
//        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: activeLens)
//    }
//}
//
//// MARK: - Tech Badge
//
//struct TechBadgeView: View {
//    let resolution: String
//    let fps: String
//
//    var body: some View {
//        HStack(spacing: 7) {
//            Text(resolution)
//                .font(.system(size: 12, weight: .black, design: .monospaced))
//                .foregroundStyle(RT.gold)
//            Rectangle()
//                .fill(Color.white.opacity(0.2))
//                .frame(width: 1, height: 12)
//            Text(fps)
//                .font(.system(size: 12, weight: .semibold, design: .monospaced))
//                .foregroundStyle(RT.dimWhite)
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 6)
//        .background(.ultraThinMaterial, in: Capsule())
//        .overlay(Capsule().stroke(RT.gold.opacity(0.22), lineWidth: 1))
//    }
//}
//
//// MARK: - Capture Button
//
//struct CaptureButton: View {
//    let isRecording: Bool
//    let action: () -> Void
//    @State private var ringPulse = false
//
//    var body: some View {
//        Button(action: action) {
//            ZStack {
//                // Outer pulse ring (recording only)
//                if isRecording {
//                    Circle()
//                        .stroke(RT.recRed.opacity(ringPulse ? 0.0 : 0.6), lineWidth: 2)
//                        .frame(width: 84, height: 84)
//                        .scaleEffect(ringPulse ? 1.22 : 1.0)
//                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false),
//                                   value: ringPulse)
//                        .onAppear { ringPulse = true }
//                }
//
//                // Main ring
//                Circle()
//                    .stroke(isRecording ? RT.recRed : .white, lineWidth: isRecording ? 2.5 : 2.5)
//                    .frame(width: 72, height: 72)
//
//                // Inner shape
//                Group {
//                    if isRecording {
//                        RoundedRectangle(cornerRadius: 5)
//                            .fill(Color.white)
//                            .frame(width: 27, height: 27)
//                    } else {
//                        Circle()
//                            .fill(Color.white)
//                            .frame(width: 58, height: 58)
//                    }
//                }
//                .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isRecording)
//            }
//        }
//        .buttonStyle(HapticButtonStyle())
//        .onChange(of: isRecording) { _, rec in ringPulse = rec }
//    }
//}
//
//struct HapticButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
//            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
//            .onChange(of: configuration.isPressed) { _, pressed in
//                if pressed { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
//            }
//    }
//}
//
//// MARK: - ControlBarView (The Dock)
//
//struct ControlBarView: View {
//    let isRecording: Bool
//    let audioLevel: Float
//    let onCapture: () -> Void
//    let onSettings: () -> Void
//    let onFlip: () -> Void
//
//    var body: some View {
//        HStack(alignment: .center, spacing: 0) {
//
//            // Leading
//            HStack(spacing: 22) {
//                Button(action: onSettings) {
//                    Image(systemName: "gearshape.fill")
//                        .font(.system(size: 18, weight: .regular))
//                        .foregroundStyle(Color.white.opacity(0.72))
//                }
//                Button(action: {}) {
//                    Image(systemName: "sun.max.fill")
//                        .font(.system(size: 20, weight: .regular))
//                        .foregroundStyle(Color.white.opacity(0.72))
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .padding(.leading, 30)
//
//            // Center
//            CaptureButton(isRecording: isRecording, action: onCapture)
//
//            // Trailing
//            HStack(spacing: 18) {
//                WaveformView(level: audioLevel)
//                    .frame(width: 62)
//                Button(action: onFlip) {
//                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
//                        .font(.system(size: 18, weight: .regular))
//                        .foregroundStyle(Color.white.opacity(0.72))
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .trailing)
//            .padding(.trailing, 30)
//        }
//        .frame(height: 90)
//        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RT.cornerDock))
//        .overlay(
//            RoundedRectangle(cornerRadius: RT.cornerDock)
//                .stroke(
//                    isRecording ? RT.recRed.opacity(0.5) : Color.white.opacity(0.11),
//                    lineWidth: isRecording ? 1.5 : 1
//                )
//        )
//        .shadow(color: .black.opacity(0.5), radius: 22, y: 8)
//        .animation(.easeInOut(duration: 0.3), value: isRecording)
//    }
//}
//
//// MARK: - CameraOverlayView (Quick Settings + Dock)
//
//struct CameraOverlayView: View {
//    
//    @ObservedObject var camera: CameraManager
//    
//    let audioLevel: Float
//    let isRecording: Bool
//    let onSettings: () -> Void
//    let onFlip: () -> Void
//    let onCapture: () -> Void
//
//    var body: some View {
//        VStack(spacing: 0) {
//            Spacer()
//
//            HStack(alignment: .center) {
//                LensSelectorView(camera: camera)
//                Spacer()
//                TechBadgeView(resolution: "4K", fps: "24fps")
//            }
//            .padding(.horizontal, 20)
//            .padding(.bottom, 12)
//
//            ControlBarView(
//                isRecording: isRecording,
//                audioLevel: audioLevel,
//                onCapture: onCapture,
//                onSettings: onSettings,
//                onFlip: onFlip
//            )
//            .padding(.horizontal, 12)
//            .padding(.bottom, 30)
//        }
//    }
//}
//
////// MARK: - Preflight Banner
////
////struct PreflightBanner: View {
////    let status: PreflightStatus
////
////    private var warnings: [(icon: String, msg: String)] {
////        var w: [(String, String)] = []
////        if status.isLowPowerMode { w.append(("bolt.slash.fill", "Low Power Mode ativo")) }
////        if !status.hasSufficientStorage {
////            w.append(("externaldrive.badge.exclamationmark",
////                      "Armazenamento: \(String(format: "%.1f", status.freeStorageGB)) GB livres"))
////        }
////        if !status.isTorchAvailable { w.append(("flashlight.off.fill", "Flash indisponível")) }
////        return w
////    }
////
////    var body: some View {
////        if !warnings.isEmpty {
////            VStack(spacing: 5) {
////                ForEach(warnings.indices, id: \.self) { i in
////                    HStack(spacing: 7) {
////                        Image(systemName: warnings[i].icon)
////                            .font(.system(size: 11, weight: .semibold))
////                            .foregroundStyle(.orange)
////                        Text(warnings[i].msg)
////                            .font(.system(size: 11, weight: .medium, design: .monospaced))
////                            .foregroundStyle(.white)
////                    }
////                    .padding(.horizontal, 12)
////                    .padding(.vertical, 6)
////                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
////                    .overlay(RoundedRectangle(cornerRadius: 8)
////                        .stroke(Color.orange.opacity(0.35), lineWidth: 1))
////                }
////            }
////            .padding(.horizontal, 16)
////        }
////    }
////}
//
//// MARK: - Error Toast
//
//struct ErrorToast: View {
//    let message: String
//    var body: some View {
//        HStack(spacing: 9) {
//            Image(systemName: "exclamationmark.triangle.fill")
//                .foregroundStyle(RT.recRed)
//                .font(.system(size: 13))
//            Text(message)
//                .font(.system(size: 12, weight: .medium, design: .monospaced))
//                .foregroundStyle(.white)
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 10)
//        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
//        .overlay(RoundedRectangle(cornerRadius: 12).stroke(RT.recRed.opacity(0.4), lineWidth: 1))
//        .padding(.horizontal, 20)
//    }
//}
//
//// MARK: - ContentView
//
//struct ContentView: View {
//    @StateObject private var camera = CameraManager()
//    @State private var currentZoom: CGFloat = 1.0
//
//    private var micLabel: String {
//        camera.selectedMic == .builtin ? "Built-in Mic" : "External Mic"
//    }
//
//    var body: some View {
//        ZStack(alignment: .top) {
//
//            
//
//            // Layer 0 —  Preview + Gesto de Pinça
//            CameraPreviewLayer(session: camera.session)
//                .ignoresSafeArea()
//                .gesture(
//                    MagnificationGesture()
//                        .onChanged { value in
//                            // value é o factor acumulado do gesto actual (começa em 1.0)
//                            // Multiplicamos pelo lastScale (factor no início deste gesto)
//                            let newFactor = camera.lastScale * value
//                            camera.setZoom(newFactor) // factor contínuo, sem label
//                        }
//                        .onEnded { value in
//                            // Guarda o factor final como base para o próximo gesto
//                            let newFactor = camera.lastScale * value
//                            camera.setZoom(newFactor)
//                            camera.lastScale = camera.currentZoomFactor
//                        }
//                )
//
//            // Layer 1 — Top bar
//            VStack(spacing: 8) {
//                TopMonitoringBar(
//                    isRecording: camera.isRecording,
//                    duration: camera.recordingDuration,
//                    micLabel: micLabel
//                )
//                Spacer()
//            }
//
//            // Layer 2 — Left VU Meter
//            HStack(alignment: .center) {
//                LevelMeterView(level: camera.audioLevel)
//                    .padding(.leading, 20)
//                    .padding(.top, 120)
//                Spacer()
//            }
//            .ignoresSafeArea(edges: .bottom)
//
//            // Layer 3 — Bottom dock + quick settings
//            CameraOverlayView(
//                camera: camera,
//                audioLevel: camera.audioLevel,
//                isRecording: camera.isRecording,
//                onSettings: {},
//                onFlip: { camera.flipCamera() },
//                onCapture: {
//                    camera.isRecording ? camera.stopRecording() : camera.startRecording()
//                }
//            )
//            .ignoresSafeArea(edges: .bottom)
//
//            // Layer 4 — Error toast
//            if let err = camera.error {
//                VStack {
//                    Spacer()
//                    ErrorToast(message: err.localizedDescription)
//                        .padding(.bottom, 160)
//                        .onTapGesture { camera.error = nil }
//                        .transition(.move(edge: .bottom).combined(with: .opacity))
//                }
//                .animation(.spring(response: 0.4), value: camera.error != nil)
//            }
//        }
//        .preferredColorScheme(.dark)
//        .statusBarHidden(true)
//        .task { await camera.boot() }
//        .onChange(of: camera.error) { _, newVal in
//            guard newVal != nil else { return }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//                if camera.error?.errorDescription == newVal?.errorDescription {
//                    camera.error = nil
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//}
