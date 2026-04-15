//
//  CameraManager.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 08/04/26.
//

internal import AVFoundation
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
    @Published var microphoneName: String = "..."
    @Published var showMicWarning: Bool = false
    @Published var micWarningMessage: String = ""
    @Published var showWhiteBalanceBar: Bool = false
    @Published var whiteBalance: Float = 0
    @Published var selectedQuality: VideoQuality = .uhd4k30
    @Published var projectName: String = "Recly"
    @Published var filePrefix: String = ""
    @Published var isCinematicEnabled: Bool = true
    @Published var isTallyLightEnabled: Bool = true
    @Published var tallyInterval: Double = 3.5
    
    private let recordingActor = RecordingStateActor()
    private let sessionActor = CameraSessionActor()
    
    private var timer: AnyCancellable?
    private var audioTimer: AnyCancellable?
    private var recordingStartDate: Date?
    private var audioRouteObserver: NSObjectProtocol?
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
            await sessionActor.applyVideoQuality(self.selectedQuality) 
            await startAudioMonitoring()
            observeAudioRouteChanges()
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        Task {
            guard await recordingActor.canStartRecording() else { return }
            
            await recordingActor.setState(.starting)
            
            let timestamp = Int(Date().timeIntervalSince1970)
            let baseName = projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Recly" : projectName
            let safeName = baseName
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "_")
            let fileName = "\(safeName)_\(timestamp).mov"
    
            await sessionActor.startRecording(delegate: recordingDelegate, fileName: fileName)
           
            if isTallyLightEnabled {
                await sessionActor.startTorchPulse(interval: tallyInterval)
            }
            
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
            await sessionActor.stopTorchPulse()
            
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
        audioTimer = Timer.publish(every: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                
                Task {
                    let level = await self.sessionActor.getAudioLevel()
                    let mic = await self.sessionActor.getCurrentMicrophoneName()
                    
                    await MainActor.run {
                        self.audioLevel = level
                        self.microphoneName = mic
                    }
                }
            }
    }
    
    private func observeAudioRouteChanges() {
        audioRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            
            Task {
                let mic = await self.sessionActor.getCurrentMicrophoneName()
                
                await MainActor.run {
                    self.microphoneName = mic
                }
                
                // 🔥 Detectar desconexão durante gravação
                if await self.isRecording {
                    await self.handleMicrophoneChange(notification: notification)
                }
            }
        }
    }
    
    private func handleMicrophoneChange(notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // 🔴 Microfone desconectado
            micWarningMessage = "Microfone desconectado"
            showMicWarning = true
            
        case .newDeviceAvailable:
            // 🟢 Novo microfone conectado
            micWarningMessage = "Microfone conectado"
            showMicWarning = true
            
        default:
            break
        }
        
        // Auto hide suave
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self.showMicWarning = false
            }
        }
    }
    
    // MARK: - Switch Camera
    func switchCamera() {
        Task {
            await sessionActor.switchCamera()
        }
    }
    
    // MARK: - Camera Effects
    
    func setWhiteBalance(_ value: Float) {
        self.whiteBalance = value
        
        Task {
            await sessionActor.setWhiteBalance(temperature: value)
        }
    }
    
    func setVideoQuality(_ quality: VideoQuality) {
        self.selectedQuality = quality
        
        Task {
            await sessionActor.applyVideoQuality(quality)
        }
    }
    
    func setCinematicEnabled(_ enabled: Bool) {
        self.isCinematicEnabled = enabled
        Task {
            await sessionActor.setCinematicEnabled(enabled)
        }
    }
    
    func sanitizeProjectName() {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.projectName = trimmed
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
