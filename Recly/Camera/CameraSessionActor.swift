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
    
    // MARK: - Setup
    
    func configureSession() async throws {
        session.beginConfiguration()
        
        session.sessionPreset = .hd4K3840x2160
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            throw NSError(domain: "Camera", code: -1)
        }
        
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
                
                // 🔥 ESTABILIZAÇÃO CINEMATOGRÁFICA (O que faz o vídeo parecer profissional)
                if let connection = videoOutput.connection(with: .video) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .cinematicExtended
                    }
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
    
    // MARK: - Zoom
    
    func setZoom(factor: CGFloat) -> CGFloat {
        guard let device = currentInput?.device else { return 1.0 }
        
        do {
            try device.lockForConfiguration()
            
            let clamped = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.ramp(toVideoZoomFactor: clamped, withRate: 2.0)
            
            device.unlockForConfiguration()
            return clamped
            
        } catch {
            return 1.0
        }
    }
    
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
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            return
        }
        
        session.beginConfiguration()
        
        // Remove input atual
        session.removeInput(currentInput)
        
        // Tenta adicionar novo
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            self.currentInput = newInput
        } else {
            // fallback (raro, mas seguro)
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
    
    func setWhiteBalance(temperature: Float) {
        guard let device = currentInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if temperature == 0 {
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
            } else {
                let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: temperature,
                    tint: 0
                )
                
                let gains = device.deviceWhiteBalanceGains(for: tempAndTint)
                
                // Clamp de segurança
                let clampedGains = AVCaptureDevice.WhiteBalanceGains(
                    redGain: max(1.0, min(gains.redGain, device.maxWhiteBalanceGain)),
                    greenGain: max(1.0, min(gains.greenGain, device.maxWhiteBalanceGain)),
                    blueGain: max(1.0, min(gains.blueGain, device.maxWhiteBalanceGain))
                )
                
                device.setWhiteBalanceModeLocked(with: clampedGains, completionHandler: nil)
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Erro White Balance: \(error)")
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
            connection.preferredVideoStabilizationMode = enabled ? .cinematicExtended : .off
        }
    }
}
