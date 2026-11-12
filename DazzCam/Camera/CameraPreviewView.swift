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
/// Tambien traduce el toque en pantalla a un punto de la camara para enfocar.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var alTocar: (CGPoint, CGPoint) -> Void = { _, _ in }

    func makeUIView(context: Context) -> PreviewLayerView {
        let vista = PreviewLayerView()
        vista.backgroundColor = .black
        vista.capa?.session = session
        vista.capa?.videoGravity = .resizeAspectFill

        let toque = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.toco(_:))
        )
        vista.addGestureRecognizer(toque)
        context.coordinator.vista = vista

        return vista
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) {
        if uiView.capa?.session !== session {
            uiView.capa?.session = session
            uiView.capa?.videoGravity = .resizeAspectFill
        }
        context.coordinator.alTocar = alTocar
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(alTocar: alTocar)
    }

    final class Coordinator: NSObject {
        var alTocar: (CGPoint, CGPoint) -> Void
        weak var vista: PreviewLayerView?

        init(alTocar: @escaping (CGPoint, CGPoint) -> Void) {
            self.alTocar = alTocar
        }

        @objc func toco(_ gesto: UITapGestureRecognizer) {
            guard let vista = vista, let capa = vista.capa else { return }
            let enVista = gesto.location(in: vista)
            let enCamara = capa.captureDevicePointConverted(fromLayerPoint: enVista)
            alTocar(enCamara, enVista)
        }
    }
}
