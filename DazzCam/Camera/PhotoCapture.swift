import AVFoundation
import UIKit
import Combine

/// Captura de fotos. Paso 3: dispara y deja la imagen en `ultimaFoto`.
final class PhotoCapture: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {

    @Published private(set) var ultimaFoto: UIImage?
    @Published private(set) var capturando = false
    @Published private(set) var error: String?
    @Published private(set) var capturas = 0

    let salida = AVCapturePhotoOutput()

    /// Agrega la salida de foto a la sesion. Debe llamarse antes de arrancar.
    func conectar(a sesion: AVCaptureSession) -> Bool {
        guard !sesion.outputs.contains(where: { $0 === salida }) else { return true }
        guard sesion.canAddOutput(salida) else { return false }

        sesion.beginConfiguration()
        sesion.addOutput(salida)
        sesion.commitConfiguration()
        return true
    }

    func disparar() {
        guard !capturando else { return }
        capturando = true
        error = nil

        let ajustes = AVCapturePhotoSettings()
        salida.capturePhoto(with: ajustes, delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.capturando = false
            }
            return
        }

        guard let datos = photo.fileDataRepresentation(),
              let imagen = UIImage(data: datos) else {
            DispatchQueue.main.async {
                self.error = "No se pudo leer la foto"
                self.capturando = false
            }
            return
        }

        DispatchQueue.main.async {
            self.ultimaFoto = imagen
            self.capturas += 1
            self.capturando = false
        }
    }
}
