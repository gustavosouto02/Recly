//
//  CameraStateActor.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import Foundation
internal import AVFoundation
import SwiftUI

actor CameraSessionActor {
    
    nonisolated let session = AVCaptureSession()
    nonisolated var unsafeSession: AVCaptureSession {
        session
    }
    private let videoOutput = AVCaptureMovieFileOutput()
    
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var torchTask: Task<Void, Never>?
    private var virtualBackCamera: AVCaptureDevice?
    private var zoomLabelMapping: [String: CGFloat] = ["0.5x": 1.0, "1x": 2.0, "2x": 4.0]
    
    // MARK: - Setup
    
    func configureSession() async throws {
        session.beginConfiguration()
        
        session.sessionPreset = .hd4K3840x2160
        
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        
        guard let camera = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            throw NSError(domain: "Camera", code: -1)
        }
        
        virtualBackCamera = camera
        
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }
        
        do {
                try camera.lockForConfiguration()
                
                // Foco contínuo e suave (Crucial para não ficar embaçado)
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
                }
                
                // Auto exposição contínua
                if camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposureMode = .continuousAutoExposure
                }
                
                // HDR Automático (Resolve luz estourada/escura)
                if camera.activeFormat.isVideoHDRSupported {
                    camera.automaticallyAdjustsVideoHDREnabled = true
                }
                
                // Priorizar qualidade sobre latência
                if camera.isGlobalToneMappingEnabled {
                    camera.isGlobalToneMappingEnabled = true
                }
                
                camera.unlockForConfiguration()
            } catch {
                print("Erro hardware: \(error)")
            }
        
        // Audio
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
            audioInput = micInput
        }
        
        if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                
                // 🔥 Estabilização AUTO para evitar crop agressivo na ultra wide
                if let connection = videoOutput.connection(with: .video),
                   connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        
        session.commitConfiguration()
        session.startRunning()
    }
    
    // MARK: - Recording
    
    func startRecording(delegate: AVCaptureFileOutputRecordingDelegate, fileName: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        videoOutput.startRecording(to: url, recordingDelegate: delegate)
    }
    
    func stopRecording() {
        videoOutput.stopRecording()
    }
    
    // MARK: - Zoom (Virtual Device)
    
    private func updateZoomLabelMappingIfPossible(for device: AVCaptureDevice) {
        guard device.isVirtualDevice else { return }
        
        // Exemplo comum em virtual device:
        // 1.0 = 0.5x óptico, ~2.0 = 1x óptico, ~4.0 = 2x óptico
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        
        if switchOvers.count >= 2 {
            zoomLabelMapping["0.5x"] = 1.0
            zoomLabelMapping["1x"] = switchOvers[0]
            zoomLabelMapping["2x"] = switchOvers[1]
        } else if switchOvers.count == 1 {
            zoomLabelMapping["0.5x"] = 1.0
            zoomLabelMapping["1x"] = switchOvers[0]
            zoomLabelMapping["2x"] = min(switchOvers[0] * 2.0, device.activeFormat.videoMaxZoomFactor)
        } else {
            zoomLabelMapping["0.5x"] = 1.0
            zoomLabelMapping["1x"] = 2.0
            zoomLabelMapping["2x"] = 4.0
        }
    }
    
    func getZoomLabelMapping() -> [String: CGFloat] {
        if let device = currentInput?.device {
            updateZoomLabelMappingIfPossible(for: device)
        }
        return zoomLabelMapping
    }
    
    func setZoom(factor: CGFloat) -> CGFloat {
        guard let device = currentInput?.device else { return 1.0 }
        
        if device.position == .back {
            updateZoomLabelMappingIfPossible(for: device)
        }
        
        do {
            try device.lockForConfiguration()
            let minZoom = max(1.0, device.minAvailableVideoZoomFactor)
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, device.maxAvailableVideoZoomFactor)
            let clamped = max(minZoom, min(factor, maxZoom))
            device.ramp(toVideoZoomFactor: clamped, withRate: 4.0)
            device.unlockForConfiguration()
            return clamped
        } catch {
            return device.videoZoomFactor
        }
    }

    // Adicione no CameraSessionActor:

//    func setFocusAndExposure(at point: CGPoint, in previewLayer: AVCaptureVideoPreviewLayer) {
//        guard let device = currentInput?.device else { return }
//        
//        let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
//        
//        do {
//            try device.lockForConfiguration()
//            
//            // 🔥 FOCO NO PONTO TOCADO (igual app nativo)
//            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
//                device.focusPointOfInterest = pointOfInterest
//                device.focusMode = .autoFocus
//            }
//            
//            // 🔥 EXPOSIÇÃO NO PONTO TOCADO (igual app nativo)
//            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
//                device.exposurePointOfInterest = pointOfInterest
//                device.exposureMode = .autoExpose
//            }
//            
//            device.unlockForConfiguration()
//        } catch {
//            print("Erro foco/exposição: \(error)")
//        }
//    }
    
    func setFocusOnly(at point: CGPoint, in previewLayer: AVCaptureVideoPreviewLayer) {
        guard let device = currentInput?.device else { return }
        
        let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        
        do {
            try device.lockForConfiguration()
            
            // 🎯 Apenas foco no ponto tocado
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = pointOfInterest
                device.focusMode = .autoFocus
            }
            
            // 📊 Exposição automática no ponto tocado (sem travar)
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = pointOfInterest
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Erro foco: \(error)")
        }
    }
    
    func restoreExposureBias(_ bias: Float) {
        guard let device = currentInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            // 🔄 Volta para exposição contínua com o bias do usuário
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
            device.setExposureTargetBias(clamped, completionHandler: nil)
            
        } catch {
            print("Erro restore bias: \(error)")
        }
    }

//    func lockExposureAtCurrent() {
//        guard let device = currentInput?.device else { return }
//        
//        do {
//            try device.lockForConfiguration()
//            
//            // 🔒 TRAVA exposição no valor atual (igual app nativo após tap)
//            if device.isExposureModeSupported(.locked) {
//                device.exposureMode = .locked
//            }
//            
//            device.unlockForConfiguration()
//        } catch {
//            print("Erro lock exposure: \(error)")
//        }
//    }
    
    // MARK: - Audio

    func getCurrentMicrophoneName() -> String {
        let session = AVAudioSession.sharedInstance()
        
        guard let input = session.currentRoute.inputs.first else {
            return "Sem microfone"
        }
        
        let portType = input.portType
        let name = input.portName.lowercased()
        
        if name.count > 3 &&
           !name.contains("microphone") &&
           !name.contains("headset") {
            return input.portName // nome real (ex: "Rode Wireless GO II")
        }
        
        switch portType {
        case .builtInMic:
            return "iPhone"
            
        case .headsetMic:
            return "Fone com fio"
            
        case .bluetoothHFP, .bluetoothLE, .bluetoothA2DP:
            return "Bluetooth"
            
        case .usbAudio:
            return "USB"
            
        default:
            return name // fallback real (tipo “Rode Wireless GO II” 🔥)
        }
    }
    
    func getAudioLevel() -> Float {
        guard let connection = videoOutput.connection(with: .audio),
              let channel = connection.audioChannels.first else {
            return -160.0
        }
        
        return channel.averagePowerLevel
    }
    
    // MARK: - Switch Camera
    func switchCamera() async {
        guard let currentInput else { return }
        
        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        let newDevice: AVCaptureDevice?
        if newPosition == .back {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            newDevice = discovery.devices.first
        } else {
            newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        
        guard let device = newDevice,
              let newInput = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            self.currentInput = newInput
        } else {
            session.addInput(currentInput)
        }
        
        session.commitConfiguration()
    }
    
    func startTorchPulse(interval: Double) {
        guard let device = currentInput?.device,
              device.hasTorch,
              device.position == .back else { return }
        
        torchTask?.cancel()
        
        torchTask = Task {
            while !Task.isCancelled {
                do {
                    try device.lockForConfiguration()
                    
                    // 🔥 intensidade bem baixa (quase imperceptível)
                    try device.setTorchModeOn(level: 0.005)
                    
                    device.unlockForConfiguration()
                    
                    try await Task.sleep(nanoseconds: 100_000_000)
                    
                    try device.lockForConfiguration()
                    device.torchMode = .off
                    device.unlockForConfiguration()
                    
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    
                } catch {
                    break
                }
            }
        }
    }
    
    func stopTorchPulse() {
        torchTask?.cancel()
        torchTask = nil
        
        guard let device = currentInput?.device,
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {}
    }
    
    func setExposureBias(_ bias: Float) {
        guard let device = currentInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            guard device.isExposureModeSupported(.continuousAutoExposure) else { return }
            let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
            device.setExposureTargetBias(clamped, completionHandler: nil)
        } catch {
            print("Erro Exposure Bias: \(error)")
        }
    }
    
    func getExposureBiasInfo() -> (Float, Float, Float, Bool) {
        guard let device = currentInput?.device else { return (-2, 2, 0, true) }
        let isAutoEnabled = abs(device.exposureTargetBias) < 0.0001
        return (device.minExposureTargetBias, device.maxExposureTargetBias, device.exposureTargetBias, isAutoEnabled)
    }
    
    func setAutoExposureEnabled(_ enabled: Bool) {
        guard let device = currentInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            device.exposureMode = .continuousAutoExposure
            
            if enabled {
                device.setExposureTargetBias(0.0, completionHandler: nil)
            } // quando false, mantém o bias atual (manual)
        } catch {
            print("Erro Auto Exposure: \(error)")
        }
    }


    
    func applyVideoQuality(_ quality: VideoQuality) {
        guard let device = currentInput?.device else { return }
        
        session.beginConfiguration()
        
        // 🎯 Mantém preset (isso é seguro)
        if session.canSetSessionPreset(quality.sessionPreset) {
                session.sessionPreset = quality.sessionPreset
            } else {
                // Se não suportar 4K, tenta um fallback para 1080p
                session.sessionPreset = .hd1920x1080
            }
        
        do {
            try device.lockForConfiguration()
            
            // 🔥 NÃO troca activeFormat agressivamente
            // deixa o iOS escolher o melhor formato
            
            let desiredFPS = Double(quality.fps)
            
            // 🎯 Ajusta FPS com segurança
            let supported = device.activeFormat.videoSupportedFrameRateRanges
            
            if let range = supported.first,
               range.minFrameRate <= desiredFPS,
               desiredFPS <= range.maxFrameRate {
                
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(quality.fps))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(quality.fps))
            }
            
            // ✅ RESTAURA COMPORTAMENTO NATIVO DO IPHONE
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Estratégia parecida com app Câmera: manter automações e mapear luz
            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = true
            }
            if device.isGlobalToneMappingEnabled {
                device.isGlobalToneMappingEnabled = true
            }
            if device.minExposureTargetBias <= 0.0 && 0.0 <= device.maxExposureTargetBias {
                device.setExposureTargetBias(0.0) { _ in }
            }
            
            // 🔥 MELHOR QUALIDADE DE IMAGEM
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            
            device.unlockForConfiguration()
            
        } catch {
            print("Erro ao aplicar qualidade: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func setCinematicEnabled(_ enabled: Bool) {
        guard let connection = videoOutput.connection(with: .video) else { return }
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = enabled ? .auto : .off
        }
    }
}
