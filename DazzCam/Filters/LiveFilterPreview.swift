import AVFoundation
import Combine
import UIKit

/// Toma los frames de la camara y publica la version filtrada.
/// Paso 6: filtro aplicado en vivo sobre el preview.
final class LiveFilterPreview: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published private(set) var imagen: UIImage?
    @Published private(set) var conectado = false
    @Published private(set) var cuadrosPorSegundo = 0

    /// Lo cambia la vista cuando el usuario elige otro filtro.
    var preset: FilterPreset = .dazzClassic

    /// Intensidad, rayones y fugas elegidos por el usuario.
    var controles = ControlesLook()

    /// Semilla del preview. Se cambia al empezar cada grabacion para que el
    /// video guardado tenga el mismo patron que estabas viendo.
    var semilla: UInt64 = 0

    let salida = AVCaptureVideoDataOutput()
    private let renderer = VideoFrameRenderer()
    private let cola = DispatchQueue(label: "com.diego.dazzcam.vivo", qos: .userInitiated)

    private var ultimoRender: CFAbsoluteTime = 0
    private let intervaloMinimo: CFAbsoluteTime = 1.0 / 60.0
    private var contadorCuadros = 0
    private var marcaContador: CFAbsoluteTime = 0

    func conectar(a sesion: AVCaptureSession) -> Bool {
        if conectado { return true }

        salida.alwaysDiscardsLateVideoFrames = true
        salida.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        salida.setSampleBufferDelegate(self, queue: cola)

        guard sesion.canAddOutput(salida) else { return false }

        sesion.beginConfiguration()
        sesion.addOutput(salida)
        sesion.commitConfiguration()

        conectado = true
        return true
    }

    func desconectar() {
        salida.setSampleBufferDelegate(nil, queue: nil)
        imagen = nil
        conectado = false
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let ahora = CFAbsoluteTimeGetCurrent()

        if connection.isVideoRotationAngleSupported(90), connection.videoRotationAngle != 90 {
            connection.videoRotationAngle = 90
        }

        guard ahora - ultimoRender >= intervaloMinimo else { return }
        ultimoRender = ahora

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let filtrada = renderer.renderizar(
            buffer,
            preset: preset,
            controles: controles,
            semilla: semilla
        ) else { return }

        contadorCuadros += 1
        if ahora - marcaContador >= 1.0 {
            let fps = contadorCuadros
            contadorCuadros = 0
            marcaContador = ahora
            DispatchQueue.main.async {
                self.cuadrosPorSegundo = fps
            }
        }

        DispatchQueue.main.async {
            self.imagen = filtrada
        }
    }
}
