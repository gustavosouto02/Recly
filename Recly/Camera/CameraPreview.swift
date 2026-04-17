//
//  CameraPreview.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 08/04/26.
//

import SwiftUI
internal import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    @ObservedObject var cameraManager: CameraManager // Use ObservedObject

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
       // view.backgroundColor = .black
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        
        // Pinch para zoom
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        
        // Tap para foco/exposição automática estilo Apple
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(manager: cameraManager)
    }

    class Coordinator: NSObject {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var cameraManager: CameraManager
        var lastZoom: CGFloat = 1.0

        init(manager: CameraManager) {
            self.cameraManager = manager
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began {
                lastZoom = cameraManager.zoomFactor
            }
            let targetZoom = lastZoom * gesture.scale
            cameraManager.zoom(factor: targetZoom)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let point = gesture.location(in: view)
            cameraManager.setFocusAndExposure(at: point, previewLayer: previewLayer!)
        }
    }
}
