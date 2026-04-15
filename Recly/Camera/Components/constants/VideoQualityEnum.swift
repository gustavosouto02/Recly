//
//  VideoQualityEnum.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 13/04/26.
//

internal import AVFoundation


enum VideoQuality: String, CaseIterable, Identifiable {
    case hd24, hd30, hd60
    case fullHD24, fullHD30, fullHD60
    case uhd4k24, uhd4k30, uhd4k60
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .hd24: return "HD • 24fps"
        case .hd30: return "HD • 30fps"
        case .hd60: return "HD • 60fps"
        case .fullHD24: return "FHD • 24fps"
        case .fullHD30: return "FHD • 30fps"
        case .fullHD60: return "FHD • 60fps"
        case .uhd4k24: return "4K • 24fps"
        case .uhd4k30: return "4K • 30fps"
        case .uhd4k60: return "4K • 60fps"
        }
    }
    
    // 🔥 Corrigido: Movido para fora da var label
    var sessionPreset: AVCaptureSession.Preset {
        if rawValue.contains("4k") { return .hd4K3840x2160 }
        if rawValue.contains("fullHD") { return .hd1920x1080 }
        return .hd1280x720
    }
    
    // 🔥 Corrigido: Movido para fora da var label
    var fps: Int32 {
        if rawValue.contains("24") { return 24 }
        if rawValue.contains("60") { return 60 }
        return 30
    }
}
