//
//  CameraStateActor.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import Foundation
import AVFoundation
import SwiftUI

actor CameraSessionActor {
    
    let session = AVCaptureSession()
    nonisolated var unsafeSession: AVCaptureSession {
        session
    }
    private let videoOutput = AVCaptureMovieFileOutput()
    
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    // MARK: - Setup
    
    func configureSession() async throws {
        session.beginConfiguration()
        
        session.sessionPreset = .hd4K3840x2160
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            throw NSError(domain: "Camera", code: -1)
        }
        
        session.addInput(input)
        currentInput = input
        
        // Audio
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
            audioInput = micInput
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
        session.startRunning()
    }
    
    // MARK: - Recording
    
    func startRecording(delegate: AVCaptureFileOutputRecordingDelegate) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        
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
}
