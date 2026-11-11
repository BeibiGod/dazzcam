import SwiftUI
import UIKit
import AVFoundation

/// UIView cuya capa principal es la capa de preview de la camara.
final class PreviewLayerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var capa: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }
}

/// Puente entre SwiftUI y la preview de AVFoundation.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewLayerView {
        let vista = PreviewLayerView()
        vista.backgroundColor = .black
        vista.capa?.session = session
        vista.capa?.videoGravity = .resizeAspectFill
        return vista
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) {
        if uiView.capa?.session !== session {
            uiView.capa?.session = session
            uiView.capa?.videoGravity = .resizeAspectFill
        }
    }
}
