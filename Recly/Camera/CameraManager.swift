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

@MainActor
class CameraManager: NSObject, ObservableObject {
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var zoomFactor: CGFloat = 1.0
    @Published var zoomMapping: [String: CGFloat] = ["0.5x": 1.0, "1x": 2.0, "2x": 4.0]
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var audioLevel: Float = -160.0
    
    private let recordingActor = RecordingStateActor()
    private let sessionActor = CameraSessionActor()
    
    private var timer: AnyCancellable?
    private var audioTimer: AnyCancellable?
    private var recordingStartDate: Date?
    var previewSession: AVCaptureSession {
        sessionActor.unsafeSession
    }
    
    private lazy var recordingDelegate = RecordingDelegate(
        actor: recordingActor,
        manager: self
    )
    
    override init() {
        super.init()
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        self.authorizationStatus = status
        
        switch status {
        case .authorized:
            setup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted { self.setup() }
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Setup
    
    func setup() {
        Task {
            try? await sessionActor.configureSession()
            await startAudioMonitoring()
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        Task {
            guard await recordingActor.canStartRecording() else { return }
            
            await recordingActor.setState(.starting)
            await sessionActor.startRecording(delegate: recordingDelegate)
            
            self.isRecording = true
            self.recordingStartDate = Date()
            
            timer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self,
                          let start = self.recordingStartDate else { return }
                    self.recordingDuration = Date().timeIntervalSince(start)
                }
        }
    }
    
    func stopRecording() {
        Task {
            guard await recordingActor.canStopRecording() else { return }
            
            await recordingActor.setState(.stopping)
            await sessionActor.stopRecording()
            
            timer?.cancel()
            timer = nil
        }
    }
    
    // MARK: - Zoom
    
    func setZoomByLabel(_ label: String) {
        guard let factor = zoomMapping[label] else { return }
        zoom(factor: factor)
    }
    
    func zoom(factor: CGFloat) {
        Task {
            let newZoom = await sessionActor.setZoom(factor: factor)
            self.zoomFactor = newZoom
        }
    }
    
    // MARK: - Audio
    
    private func startAudioMonitoring() async {
        audioTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                
                Task {
                    let level = await self.sessionActor.getAudioLevel()
                    await MainActor.run {
                        self.audioLevel = level
                    }
                }
            }
    }
    
    // MARK: - Switch Camera
    func switchCamera() {
        Task {
            await sessionActor.switchCamera()
        }
    }
}

final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    
    let actor: RecordingStateActor
    weak var manager: CameraManager?
    
    init(actor: RecordingStateActor, manager: CameraManager) {
        self.actor = actor
        self.manager = manager
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        
        Task {
            await actor.setState(.recording)
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo url: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        
        Task {
            await actor.setState(.idle)
            
            await MainActor.run {
                self.manager?.isRecording = false
            }
            
            if let error {
                print("Erro: \(error.localizedDescription)")
                return
            }
            
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
            } catch {
                print("Erro ao salvar: \(error.localizedDescription)")
            }
        }
    }
}
