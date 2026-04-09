//
//  CameraManager.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 08/04/26.
//

import AVFoundation
import SwiftUI
import Combine
import Photos


class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var isRecording: Bool = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var zoomMapping: [String: CGFloat] = ["0.5x": 1.0, "1x": 2.0, "2x": 4.0]
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = -160.0
    
    private var audioTimer: AnyCancellable?
    private var timer: AnyCancellable?
    private var recordingStartDate: Date?
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    private let sessionQueue = DispatchQueue(label: "com.recly.sessionQueue")

    override init() {
        super.init()
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func checkAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        switch status {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted { self.setupSession() }
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            self.session.sessionPreset = .hd4K3840x2160
            
            let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera]
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .back)
            
            guard let camera = discovery.devices.first else {
                if let wideCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: wideCamera) {
                    self.session.addInput(input)
                    self.currentInput = input
                }
                self.session.commitConfiguration()
                return
            }
            
            if let input = try? AVCaptureDeviceInput(device: camera), self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentInput = input
                
                // --- MELHORIA DE FOCO E QUALIDADE ---
                do {
                    try camera.lockForConfiguration()
                    
                    if camera.isFocusModeSupported(.continuousAutoFocus) {
                        camera.focusMode = .continuousAutoFocus
                    }
                    
                    if camera.isVideoHDREnabled {
                        camera.automaticallyAdjustsVideoHDREnabled = true
                    }
                    
                    camera.unlockForConfiguration()
                } catch {
                    print("Erro ao configurar foco: \(error)")
                }
                
                let factors = [1.0] + camera.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
                
                if let mainIndex = camera.constituentDevices.firstIndex(where: { $0.deviceType == .builtInWideAngleCamera }) {
                    let systemFactorFor1x = factors[mainIndex]
                    
                    DispatchQueue.main.async {
                        self.zoomMapping["0.5x"] = 1.0
                        self.zoomMapping["1x"] = systemFactorFor1x
                        
                        if factors.count > 2 {
                            self.zoomMapping["2x"] = factors[2]
                        } else {
                            self.zoomMapping["2x"] = systemFactorFor1x * 2.0
                        }

                        self.zoom(factor: 1.0)
                    }
                }
            }

            if let mic = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(micInput) {
                self.session.addInput(micInput)
                self.audioInput = micInput
            }
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                
                if let connection = self.videoOutput.connection(with: .video) {
                    if connection.isVideoStabilizationSupported {
                        // .auto ou .off para evitar o zoom forçado. .cinematic causa crop.
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
            }
            
            self.session.commitConfiguration()
            startAudioMonitoring()
            self.session.startRunning()

        }
    }

    func switchCamera() {
        sessionQueue.async {
            let currentPosition = self.currentInput?.device.position ?? .back
            let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }
            
            self.session.beginConfiguration()
            
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            } else {
                self.session.addInput(self.currentInput!)
            }
            
            self.session.commitConfiguration()
        }
    }

    func setZoomByLabel(_ label: String) {
        if let factor = zoomMapping[label] {
            self.zoom(factor: factor)
        }
    }

    func zoom(factor: CGFloat) {
        guard let device = currentInput?.device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clamped = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
                
                device.ramp(toVideoZoomFactor: clamped, withRate: 2.0)
                
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                }
                device.unlockForConfiguration()
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }
    

    func startRecording() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingDuration = 0
            self.recordingStartDate = Date()
            
            self.timer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink {
                    [weak self] _ in
                    guard let self = self, let start = self.recordingStartDate else { return }
                    self.recordingDuration = Date().timeIntervalSince(start)
                }
        }
    }
    
    private func startAudioMonitoring() {
        audioTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Buscamos a conexão de áudio no output de vídeo
                if let connection = self.videoOutput.connection(with: .audio) {
                    let channels = connection.audioChannels
                    if let firstChannel = channels.first {
                        self.audioLevel = firstChannel.averagePowerLevel
                    }
                }
            }
    }

    func stopRecording() {
        videoOutput.stopRecording()
        DispatchQueue.main.async {
            self.isRecording = false
            self.timer?.cancel()
            self.timer = nil
        }
    }
    

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        if let error = error {
            print("Erro na gravação: \(error.localizedDescription)")
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        })
    }
}
