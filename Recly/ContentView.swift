//
//  ContentView.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 08/04/26.
//

import AVFoundation
import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camada 0: Câmera
            if cameraManager.authorizationStatus == .authorized {
                CameraPreview(session: cameraManager.previewSession, cameraManager: cameraManager)
                    .ignoresSafeArea()

            } else if cameraManager.authorizationStatus == .denied {
                VStack(spacing: 20) {
                    Image(systemName: "camera.meter.嶺.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)
                    Text("Acesso à Câmera Negado")
                        .font(.headline)
                    Button("Abrir Ajustes") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            if cameraManager.authorizationStatus == .authorized {
                VStack{
                    TopStatusBarView(cameraManager: cameraManager)
                    
                    Spacer()
                    
                    HStack(alignment: .top){
                        VerticalLevelMeterView(level: cameraManager.audioLevel)
                        
                        Spacer()
                        
                    }
                    .padding(.leading, 30)

                    
                    Spacer()
                        
                    if cameraManager.showWhiteBalanceBar {
                        WhiteBalancePresetBarView(cameraManager: cameraManager)
                            .padding(.bottom, 8)
                    }
                    
                    ZoomControlView(cameraManager: cameraManager)
                    
                    // A Ilha de Comandos (O Dock)
                    ControlBarView(cameraManager: cameraManager)
                        .padding(.horizontal, 12)

                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            cameraManager.checkAuthorization()
        }
    }
}

#Preview {
    ContentView()
}
