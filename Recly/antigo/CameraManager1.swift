////
////  CameraManager.swift
////  Recly
////
////  Refactored by: iOS AVFoundation Expert
////  Fix: zoom mapping, 4K/24fps format selection, continuous AF/AE, UI sync
////
//
//import Photos
//import Foundation
//import AVFoundation
//import Combine
//import SwiftUI
//
//// MARK: - Error Types
//
//enum ReclyError: LocalizedError, Equatable {
//    case permissionDenied(String)
//    case deviceUnavailable(String)
//    case sessionFailed(String)
//    case storageInsufficient
//    case torchUnavailable
//
//    var errorDescription: String? {
//        switch self {
//        case .permissionDenied(let d): return "Permissão negada: \(d)"
//        case .deviceUnavailable(let d): return "Dispositivo indisponível: \(d)"
//        case .sessionFailed(let r): return "Sessão falhou: \(r)"
//        case .storageInsufficient: return "Armazenamento insuficiente (< 500 MB)"
//        case .torchUnavailable: return "Torch indisponível neste dispositivo"
//        }
//    }
//}
//
//enum MicrophoneSource: String, CaseIterable, Identifiable {
//    case builtin = "Interno"
//    case external = "Externo (Lightning/BT)"
//    var id: String { rawValue }
//}
//
//struct PreflightStatus {
//    var isLowPowerMode: Bool = false
//    var hasSufficientStorage: Bool = true
//    var isTorchAvailable: Bool = true
//    var freeStorageGB: Double = 0
//    var isReady: Bool { hasSufficientStorage }
//}
//
//// MARK: - Zoom Map
////
//// O sistema de coordenadas do iOS para dispositivos virtuais:
////   videoZoomFactor 1.0          → lente mais aberta (Ultra-Wide = "0.5x" ótico)
////   virtualDeviceSwitchOverVideoZoomFactors[0] → Wide Angle ("1x" ótico)
////   virtualDeviceSwitchOverVideoZoomFactors[1] → Telefoto ("2x" ótico)  [apenas Pro]
////
//// Esta struct encapsula esse mapeamento e torna o resto do código simples e correto.
//
//struct ZoomMap {
//    let ultraWide: CGFloat = 1.0
//        let wide: CGFloat
//        let tele: CGFloat
//
//        init(device: AVCaptureDevice) {
//            let factors = device.virtualDeviceSwitchOverVideoZoomFactors
//
//            if factors.count >= 2 {
//                wide = CGFloat(truncating: factors[0])
//                tele = CGFloat(truncating: factors[1])
//            } else if factors.count == 1 {
//                wide = CGFloat(truncating: factors[0])
//                tele = CGFloat(truncating: factors[0]) * 2.0
//            } else {
//                wide = 1.0
//                tele = 2.0
//            }
//        }
//    
//    static var defaultMap: ZoomMap {
//            // Retorna um mapa genérico para evitar que a UI mostre erro antes do boot
//            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
//            if let device = discovery.devices.first {
//                return ZoomMap(device: device)
//            }
//            return ZoomMap(wide: 1.0, tele: 2.0)
//        }
//
//        private init(wide: CGFloat, tele: CGFloat) {
//            self.wide = wide
//            self.tele = tele
//        }
//
//    /// Converte o label do botão (0.5x / 1x / 2x) para o factor interno do iOS
//    func internalFactor(for label: String) -> CGFloat {
//        switch label {
//        case "0.5x": return ultraWide
//        case "1x":   return wide
//        case "2x":   return tele
//        default:     return wide
//        }
//    }
//
//    /// Determina qual botão deve estar ativo dado o factor interno atual
//    func activeLabel(for currentFactor: CGFloat) -> String {
//        if currentFactor < wide - 0.15 {
//            return "0.5x"
//        } else if currentFactor < tele - 0.15 {
//            return "1x"
//        } else {
//            return "2x"
//        }
//    }
//}
//
//// MARK: - CameraManager
//
//@MainActor
//final class CameraManager: NSObject, ObservableObject {
//
//    // MARK: Published State
//    @Published var isRecording = false
//    @Published var audioLevel: Float = -160
//    @Published var selectedMic: MicrophoneSource = .builtin
//    @Published var error: ReclyError?
//    @Published var preflightStatus = PreflightStatus()
//    @Published var recordingDuration: TimeInterval = 0
//    @Published var isTorchActive = false
//    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
//
//
//    // MARK: Session
//    let session = AVCaptureSession()
//    private var videoDeviceInput: AVCaptureDeviceInput?
//    private var audioDeviceInput: AVCaptureDeviceInput?
//    private var movieOutput = AVCaptureMovieFileOutput()
//
//    // MARK: Zoom
//    @Published var currentZoomFactor: CGFloat = 1.0
//    @Published private(set) var zoomMap: ZoomMap?
//    var lastScale: CGFloat = 1.0
//    private var ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
//    private var wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
//    private var teleDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
//
//    // MARK: Timers / State
//    private var flashTimer: AnyCancellable?
//    private var flashState = false
//    private let flashInterval: TimeInterval = 1.0
//    private var audioLevelTimer: AnyCancellable?
//    private var durationTimer: AnyCancellable?
//    private var recordingStart: Date?
//    private(set) var currentOutputURL: URL?
//
//    // MARK: - Boot
//
//    func boot() async {
//        await runPreflight()
//        let granted = await requestPermissions()
//        if granted { configureSession() }
//    }
//
//    private func runPreflight() async {
//        var status = PreflightStatus()
//        status.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
//
//        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
//           let free = attrs[.systemFreeSize] as? NSNumber {
//            let freeGB = free.doubleValue / 1_073_741_824
//            status.freeStorageGB = freeGB
//            status.hasSufficientStorage = freeGB > 0.5
//        }
//
//        if let device = AVCaptureDevice.default(for: .video) {
//            status.isTorchAvailable = device.hasTorch && device.isTorchAvailable
//        } else {
//            status.isTorchAvailable = false
//        }
//        preflightStatus = status
//    }
//
//    private func requestPermissions() async -> Bool {
//        var videoGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
//        var audioGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
//
//        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
//            videoGranted = await AVCaptureDevice.requestAccess(for: .video)
//        }
//        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
//            audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
//        }
//
//        if !videoGranted { error = .permissionDenied("Câmera") }
//        else if !audioGranted { error = .permissionDenied("Microfone") }
//        return videoGranted && audioGranted
//    }
//
//    // MARK: - Session Configuration
//
//    private func configureSession() {
//        session.beginConfiguration()
//        defer { session.commitConfiguration() }
//        session.sessionPreset = .inputPriority
//
//        guard let videoDevice = bestVideoDevice() else {
//            error = .deviceUnavailable("Câmera traseira"); return
//        }
//
//        // Calcula o mapa de zoom para este dispositivo
//        let map = ZoomMap(device: videoDevice)
//        self.zoomMap = map
//
//        do {
//            let vInput = try AVCaptureDeviceInput(device: videoDevice)
//            guard session.canAddInput(vInput) else { error = .sessionFailed("Video input"); return }
//            session.addInput(vInput)
//            videoDeviceInput = vInput
//        } catch {
//            self.error = .sessionFailed(error.localizedDescription); return
//        }
//
//        // Configura formato e modo câmera ANTES de commitar
//        configureVideoDevice(videoDevice)
//
//        // Inicia na Wide (1x ótico) para uma experiência consistente com a app nativa
//        applyZoomFactor(map.wide, to: videoDevice)
//
//        refreshAudioInput(for: selectedMic)
//
//        guard session.canAddOutput(movieOutput) else { error = .sessionFailed("Movie output"); return }
//        session.addOutput(movieOutput)
//
//        if let connection = movieOutput.connection(with: .video) {
//            connection.isVideoMirrored = false
//            if connection.isVideoStabilizationSupported {
//                connection.preferredVideoStabilizationMode = .cinematic
//            }
//        }
//
//        Task.detached(priority: .userInitiated) { [weak self] in
//            await self?.session.startRunning()
//        }
//
//        startAudioLevelMonitoring()
//    }
//
//    // MARK: - Device Selection
//    
//    // MARK: - Troca de Lente Física (0.5x, 1x, 2x)
//    func switchPhysicalLens(to label: String) {
//        guard !isRecording else { return }
//        
//        let targetDevice: AVCaptureDevice?
//        switch label {
//        case "0.5x": targetDevice = ultraWideDevice
//        case "1x":   targetDevice = wideDevice
//        case "2x":   targetDevice = teleDevice ?? wideDevice // Fallback se não tiver Tele
//        default:     targetDevice = wideDevice
//        }
//        
//        guard let device = targetDevice else { return }
//        
//        session.beginConfiguration()
//        // Remove o input atual
//        if let currentInput = videoDeviceInput {
//            session.removeInput(currentInput)
//        }
//        
//        // Adiciona a nova lente física
//        do {
//            let newInput = try AVCaptureDeviceInput(device: device)
//            if session.canAddInput(newInput) {
//                session.addInput(newInput)
//                videoDeviceInput = newInput
//                
//                // Configura a qualidade nativa daquela lente específica
//                configureVideoDevice(device)
//                
//                // RESET do zoom: Como é uma lente nova, o zoom dela volta a ser 1.0 (nativo dela)
//                device.videoZoomFactor = 1.0
//                self.currentZoomFactor = 1.0
//            }
//        } catch {
//            print("Erro ao trocar para lente física: \(label)")
//        }
//        session.commitConfiguration()
//    }
//
//    private func bestVideoDevice(position: AVCaptureDevice.Position = .back) -> AVCaptureDevice? {
//        // A ordem importa: queremos o melhor dispositivo virtual disponível
//        let deviceTypes: [AVCaptureDevice.DeviceType] = [
//            .builtInTripleCamera,    // iPhone Pro (UW + W + T)
//            .builtInDualWideCamera,  // iPhone standard (UW + W)
//            .builtInDualCamera,      // iPhones mais antigos (W + T)
//            .builtInWideAngleCamera  // Fallback / front camera
//        ]
//        let discovery = AVCaptureDevice.DiscoverySession(
//            deviceTypes: deviceTypes,
//            mediaType: .video,
//            position: position
//        )
//        return discovery.devices.first
//    }
//
//    // MARK: - Format & Quality Configuration
//
//    /// Configura activeFormat para 4K/24fps (ideal pro look cinemático) com fallback para 4K/30fps e 1080p.
//    /// Ativa AF contínuo, AE contínuo, AWB contínuo e HDR quando disponível.
//    private func configureVideoDevice(_ device: AVCaptureDevice) {
//        guard let format = bestFormat(for: device) else { return }
//
//        do {
//            try device.lockForConfiguration()
//            device.activeFormat = format
//
//            // Frame rate: prioriza 24fps para look cinemático, fallback 30fps
//            let targetFPS: Double = 24
//            if let range = format.videoSupportedFrameRateRanges.first(where: { $0.maxFrameRate >= targetFPS && $0.minFrameRate <= targetFPS }) {
//                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
//                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
//            } else if let range = format.videoSupportedFrameRateRanges.first(where: { $0.maxFrameRate >= 30 }) {
//                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
//                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
//            }
//
//            // Auto Focus: contínuo + smooth para transições suaves
//            if device.isFocusModeSupported(.continuousAutoFocus) {
//                device.focusMode = .continuousAutoFocus
//            }
//            if device.isSmoothAutoFocusSupported {
//                device.isSmoothAutoFocusEnabled = true
//            }
//
//            // Auto Exposure: contínuo
//            if device.isExposureModeSupported(.continuousAutoExposure) {
//                device.exposureMode = .continuousAutoExposure
//            }
//
//            // Auto White Balance: contínuo
//            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
//                device.whiteBalanceMode = .continuousAutoWhiteBalance
//            }
//
//            // HDR: melhora o range dinâmico sem custo
//            if format.isVideoHDRSupported {
//                if device.automaticallyAdjustsVideoHDREnabled {
//                    device.automaticallyAdjustsVideoHDREnabled = false
//                }
//                device.isVideoHDREnabled = true
//            }
//
//            device.unlockForConfiguration()
//        } catch {
//            self.error = .sessionFailed("Configuração da câmera: \(error.localizedDescription)")
//        }
//    }
//
//    /// Seleciona o melhor formato disponível. Estratégia:
//    /// 4K 24fps → 4K 30fps → 4K 60fps → 1080p 30fps
//    /// Nota: em dispositivos mais antigos, 4K pode não estar disponível com Ultra-Wide.
//    private func bestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
//        let candidates = device.formats.filter { format in
//            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//            return dims.width >= 3840 // 4K
//        }
//
//        // 4K/24fps (cinemático)
//        if let f = candidates.last(where: { $0.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 24 && $0.maxFrameRate < 60 } }) {
//            return f
//        }
//        // 4K/30fps
//        if let f = candidates.last(where: { $0.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 } }) {
//            return f
//        }
//        // 4K qualquer
//        if let f = candidates.last { return f }
//
//        // Fallback: 1080p
//        return device.formats.last { format in
//            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//            return dims.width == 1920 && dims.height == 1080
//        }
//    }
//
//    // MARK: - Zoom API (pública)
//
//    /// Define o zoom usando o label do botão da UI ("0.5x", "1x", "2x") ou um factor contínuo (gesto de pinça).
//    /// Aceita factores internos do iOS directamente quando chamado pelo gesto de pinça.
//    func setZoom(_ factor: CGFloat, fromLabel label: String? = nil) {
//        guard let device = videoDeviceInput?.device else { return }
//
//        let targetFactor: CGFloat
//        if let label {
//            targetFactor = zoomMap!.internalFactor(for: label)
//        } else {
//            // Gesto de pinça: factor é um delta multiplicativo, já calculado na View
//            targetFactor = factor
//        }
//
//        applyZoomFactor(targetFactor, to: device)
//    }
//
//    private func applyZoomFactor(_ factor: CGFloat, to device: AVCaptureDevice) {
//        let clamped = max(device.minAvailableVideoZoomFactor,
//                          min(factor, device.maxAvailableVideoZoomFactor))
//        do {
//            try device.lockForConfiguration()
//            // rampToVideoZoomFactor dá uma transição suave — ideal para botões
//            device.ramp(toVideoZoomFactor: clamped, withRate: 20.0)
//            device.unlockForConfiguration()
//            self.currentZoomFactor = clamped
//            self.lastScale = clamped
//        } catch {
//            print("Erro zoom: \(error)")
//        }
//    }
//
//    // MARK: - Flip Camera
//
//    func flipCamera() {
//        guard !isRecording else { return }
//        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
//
//        session.beginConfiguration()
//        defer { session.commitConfiguration() }
//
//        if let old = videoDeviceInput { session.removeInput(old) }
//
//        guard let newDevice = bestVideoDevice(position: newPosition) else { return }
//
//        do {
//            let newInput = try AVCaptureDeviceInput(device: newDevice)
//            guard session.canAddInput(newInput) else { return }
//            session.addInput(newInput)
//            videoDeviceInput = newInput
//            currentCameraPosition = newPosition
//
//            let map = ZoomMap(device: newDevice)
//            self.zoomMap = map
//
//            configureVideoDevice(newDevice)
//            // Câmera frontal não tem Ultra-Wide → começa na Wide
//            applyZoomFactor(map.wide, to: newDevice)
//
//            if let connection = movieOutput.connection(with: .video) {
//                connection.isVideoMirrored = (newPosition == .front)
//                if connection.isVideoStabilizationSupported {
//                    connection.preferredVideoStabilizationMode = .cinematic
//                }
//            }
//        } catch {
//            self.error = .sessionFailed("Erro ao virar câmera")
//        }
//    }
//
//    // MARK: - Audio Input
//
//    func switchMicrophone(to source: MicrophoneSource) {
//        guard !isRecording else { return }
//        selectedMic = source
//        session.beginConfiguration()
//        if let existing = audioDeviceInput { session.removeInput(existing) }
//        refreshAudioInput(for: source)
//        session.commitConfiguration()
//    }
//
//    private func refreshAudioInput(for source: MicrophoneSource) {
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(.playAndRecord, mode: .videoRecording,
//                                          options: [.allowBluetooth, .allowBluetoothA2DP])
//            try audioSession.setActive(true)
//            let inputs = audioSession.availableInputs ?? []
//            let preferred = source == .external
//                ? inputs.first(where: { $0.portType != .builtInMic }) ?? inputs.first
//                : inputs.first(where: { $0.portType == .builtInMic })
//            try audioSession.setPreferredInput(preferred)
//        } catch {
//            self.error = .sessionFailed("AVAudioSession: \(error.localizedDescription)")
//        }
//
//        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
//        do {
//            let aInput = try AVCaptureDeviceInput(device: audioDevice)
//            if session.canAddInput(aInput) {
//                session.addInput(aInput)
//                audioDeviceInput = aInput
//            }
//        } catch {
//            self.error = .sessionFailed("Audio input: \(error.localizedDescription)")
//        }
//    }
//
//    // MARK: - Audio Level Monitoring
//
//    private func startAudioLevelMonitoring() {
//        audioLevelTimer = Timer.publish(every: 0.05, on: .main, in: .common)
//            .autoconnect()
//            .sink { [weak self] _ in self?.pollAudioLevel() }
//    }
//
//    private func pollAudioLevel() {
//        guard let conn = movieOutput.connections.first(where: { !$0.audioChannels.isEmpty }),
//              let ch = conn.audioChannels.first else { return }
//        audioLevel = ch.averagePowerLevel
//    }
//
//    // MARK: - Recording Control
//
//    func startRecording() {
//        guard !isRecording, session.isRunning else {
//            if !session.isRunning { self.error = .sessionFailed("A câmera não está pronta.") }
//            return
//        }
//        let url = buildOutputURL()
//        currentOutputURL = url
//        movieOutput.startRecording(to: url, recordingDelegate: self)
//        isRecording = true
//        recordingStart = Date()
//        startFlashFeedbackLoop()
//        startDurationTimer()
//    }
//
//    func stopRecording() {
//        guard isRecording else { return }
//        movieOutput.stopRecording()
//        stopFlashFeedbackLoop()
//        stopDurationTimer()
//        isRecording = false
//    }
//
//    // MARK: - Flash PWM Loop
//
//    private func startFlashFeedbackLoop() {
//        guard currentCameraPosition == .back, preflightStatus.isTorchAvailable else { return }
//        flashState = true
//        setTorch(on: true)
//        flashTimer = Timer.publish(every: flashInterval, on: .main, in: .common)
//            .autoconnect()
//            .sink { [weak self] _ in
//                guard let self else { return }
//                self.flashState.toggle()
//                self.setTorch(on: self.flashState)
//            }
//    }
//
//    private func stopFlashFeedbackLoop() {
//        flashTimer?.cancel()
//        flashTimer = nil
//        setTorch(on: false)
//        flashState = false
//        isTorchActive = false
//    }
//
//    private func setTorch(on: Bool) {
//        guard let device = videoDeviceInput?.device,
//              device.hasTorch, device.isTorchAvailable else { return }
//        do {
//            try device.lockForConfiguration()
//            if on { try device.setTorchModeOn(level: 0.001) }
//            else { device.torchMode = .off }
//            device.unlockForConfiguration()
//            isTorchActive = on
//        } catch {}
//    }
//
//    // MARK: - Duration Timer
//
//    private func startDurationTimer() {
//        recordingDuration = 0
//        durationTimer = Timer.publish(every: 0.1, on: .main, in: .common)
//            .autoconnect()
//            .sink { [weak self] _ in
//                guard let self, let start = self.recordingStart else { return }
//                self.recordingDuration = Date().timeIntervalSince(start)
//            }
//    }
//
//    private func stopDurationTimer() {
//        durationTimer?.cancel()
//        durationTimer = nil
//    }
//
//    // MARK: - Output URL
//
//    private func buildOutputURL() -> URL {
//        let fmt = DateFormatter()
//        fmt.dateFormat = "yyyyMMdd_HHmmss"
//        let name = "Recly_\(fmt.string(from: Date())).mov"
//        return FileManager.default
//            .urls(for: .documentDirectory, in: .userDomainMask)[0]
//            .appendingPathComponent(name)
//    }
//}
//
//// MARK: - AVCaptureFileOutputRecordingDelegate
//
//extension CameraManager: AVCaptureFileOutputRecordingDelegate {
//    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
//                                didFinishRecordingTo url: URL,
//                                from connections: [AVCaptureConnection],
//                                error: Error?) {
//        if let error {
//            print("❌ Erro ao gravar: \(error.localizedDescription)")
//            return
//        }
//        print("✅ Vídeo temporário: \(url.path)")
//
//        PHPhotoLibrary.requestAuthorization { status in
//            guard status == .authorized || status == .limited else {
//                print("⚠️ Permissão de Galeria negada.")
//                return
//            }
//            PHPhotoLibrary.shared().performChanges({
//                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
//            }) { success, err in
//                if success {
//                    print("⭐️ Salvo na Galeria!")
//                    try? FileManager.default.removeItem(at: url)
//                } else if let err {
//                    print("❌ Galeria: \(err.localizedDescription)")
//                }
//            }
//        }
//    }
//}
