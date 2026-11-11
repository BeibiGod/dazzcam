import AVFoundation
import Combine

/// Maneja la sesion de camara. Paso 2: solo preview en vivo, sin capturar.
@MainActor
final class CameraSession: NSObject, ObservableObject {

    enum Estado: Equatable {
        case configurando
        case listo
        case denegado
        case error(String)

        var descripcion: String {
            switch self {
            case .configurando:
                return "Preparando camara..."
            case .listo:
                return "Camara lista"
            case .denegado:
                return "Permiso de camara denegado. Activalo en Ajustes."
            case .error(let detalle):
                return detalle
            }
        }
    }

    @Published private(set) var estado: Estado = .configurando

    let session = AVCaptureSession()

    private let cola = DispatchQueue(label: "com.diego.dazzcam.camara")
    private var configurada = false
    private var arrancada = false

    func arrancar() async {
        guard await pedirPermiso() else {
            estado = .denegado
            return
        }

        let ok = await configurar()
        guard ok else {
            estado = .error("No encontre una camara disponible")
            return
        }

        estado = .listo

        if !arrancada {
            arrancada = true
            cola.async { [session] in
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }
    }

    func detener() {
        guard arrancada else { return }
        arrancada = false
        cola.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Permisos

    private func pedirPermiso() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    // MARK: - Configuracion

    private func configurar() async -> Bool {
        if configurada { return true }

        return await withCheckedContinuation { (continuacion: CheckedContinuation<Bool, Never>) in
            cola.async {
                let sesion = self.session
                sesion.beginConfiguration()
                sesion.sessionPreset = .photo

                var exito = false

                if let dispositivo = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let entrada = try? AVCaptureDeviceInput(device: dispositivo),
                   sesion.canAddInput(entrada) {
                    sesion.addInput(entrada)
                    exito = true
                }

                sesion.commitConfiguration()
                self.configurada = exito
                continuacion.resume(returning: exito)
            }
        }
    }
}
