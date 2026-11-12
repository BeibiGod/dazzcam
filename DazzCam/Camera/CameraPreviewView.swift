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
/// Traduce el toque en pantalla para enfocar y el doble toque para voltear.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var alTocar: (CGPoint, CGPoint) -> Void = { _, _ in }
    var alTocarDoble: () -> Void = {}

    func makeUIView(context: Context) -> PreviewLayerView {
        let vista = PreviewLayerView()
        vista.backgroundColor = .black
        vista.capa?.session = session
        vista.capa?.videoGravity = .resizeAspectFill

        let doble = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.tocoDoble(_:))
        )
        doble.numberOfTapsRequired = 2
        vista.addGestureRecognizer(doble)

        let toque = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.toco(_:))
        )
        toque.require(toFail: doble)
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
        context.coordinator.alTocarDoble = alTocarDoble
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(alTocar: alTocar, alTocarDoble: alTocarDoble)
    }

    final class Coordinator: NSObject {
        var alTocar: (CGPoint, CGPoint) -> Void
        var alTocarDoble: () -> Void
        weak var vista: PreviewLayerView?

        init(alTocar: @escaping (CGPoint, CGPoint) -> Void, alTocarDoble: @escaping () -> Void) {
            self.alTocar = alTocar
            self.alTocarDoble = alTocarDoble
        }

        @objc func toco(_ gesto: UITapGestureRecognizer) {
            guard let vista = vista, let capa = vista.capa else { return }
            let enVista = gesto.location(in: vista)
            let enCamara = capa.captureDevicePointConverted(fromLayerPoint: enVista)
            alTocar(enCamara, enVista)
        }

        @objc func tocoDoble(_ gesto: UITapGestureRecognizer) {
            alTocarDoble()
        }
    }
}
