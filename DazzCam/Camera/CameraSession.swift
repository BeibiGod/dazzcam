import AVFoundation
import Combine

/// Lentes traseras del telefono.
enum Lente: String, CaseIterable, Identifiable {
    case ultra = "0.5"
    case ancha = "1"
    case tele = "3"

    var id: String { rawValue }

    var etiqueta: String { rawValue + "x" }

    var tipo: AVCaptureDevice.DeviceType {
        switch self {
        case .ultra: return .builtInUltraWideCamera
        case .ancha: return .builtInWideAngleCamera
        case .tele: return .builtInTelephotoCamera
        }
    }

    static func existe(_ lente: Lente) -> Bool {
        AVCaptureDevice.default(lente.tipo, for: .video, position: .back) != nil
    }
}

/// Maneja la sesion de camara: lentes, foco y arranque.
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
    @Published private(set) var lente: Lente = .ancha
    @Published private(set) var lentes: [Lente] = []

    let session = AVCaptureSession()

    private let cola = DispatchQueue(label: "com.diego.dazzcam.camara")
    private var configurada = false
    private var arrancada = false
    private var entrada: AVCaptureDeviceInput?
    private var dispositivo: AVCaptureDevice?

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

    // MARK: - Lentes

    func cambiarLente(_ nueva: Lente) {
        guard nueva != lente else { return }

        let disponibles = lentes
        guard disponibles.isEmpty || disponibles.contains(nueva) else { return }

        cola.async {
            guard let dispositivo = AVCaptureDevice.default(
                nueva.tipo, for: .video, position: .back
            ) else { return }

            guard let entradaNueva = try? AVCaptureDeviceInput(device: dispositivo) else {
                return
            }

            let sesion = self.session
            sesion.beginConfiguration()

            let entradaVieja = self.entrada
            if let vieja = entradaVieja {
                sesion.removeInput(vieja)
            }

            if sesion.canAddInput(entradaNueva) {
                sesion.addInput(entradaNueva)
                self.entrada = entradaNueva
                self.dispositivo = dispositivo
                self.ajustarEnfoqueInicial(dispositivo)
                DispatchQueue.main.async {
                    self.lente = nueva
                }
            } else if let vieja = entradaVieja, sesion.canAddInput(vieja) {
                // si la lente nueva no entra, se regresa a la anterior
                sesion.addInput(vieja)
                self.entrada = vieja
            }

            sesion.commitConfiguration()
        }
    }

    // MARK: - Enfoque

    /// `punto` viene en coordenadas de la camara (0..1), ya convertidas
    /// desde el toque en pantalla por la capa de preview.
    func enfocar(en punto: CGPoint) {
        guard let dispositivo = dispositivo else { return }

        let x = min(max(punto.x, 0), 1)
        let y = min(max(punto.y, 0), 1)
        let destino = CGPoint(x: x, y: y)

        do {
            try dispositivo.lockForConfiguration()

            if dispositivo.isFocusPointOfInterestSupported {
                dispositivo.focusPointOfInterest = destino
                dispositivo.focusMode = .autoFocus
            }

            if dispositivo.isExposurePointOfInterestSupported {
                dispositivo.exposurePointOfInterest = destino
                dispositivo.exposureMode = .autoExpose
            }

            dispositivo.unlockForConfiguration()
        } catch {
            // si el telefono no deja mover el foco, no pasa nada: se queda como estaba
        }
    }

    private nonisolated func ajustarEnfoqueInicial(_ dispositivo: AVCaptureDevice) {
        do {
            try dispositivo.lockForConfiguration()
            if dispositivo.isFocusModeSupported(.continuousAutoFocus) {
                dispositivo.focusMode = .continuousAutoFocus
            }
            if dispositivo.isExposureModeSupported(.continuousAutoExposure) {
                dispositivo.exposureMode = .continuousAutoExposure
            }
            dispositivo.unlockForConfiguration()
        } catch {
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

        let disponibles = Lente.allCases.filter { Lente.existe($0) }

        return await withCheckedContinuation { (continuacion: CheckedContinuation<Bool, Never>) in
            cola.async {
                let sesion = self.session
                sesion.beginConfiguration()
                sesion.sessionPreset = .photo

                let inicial: Lente = disponibles.contains(.ancha) ? .ancha : (disponibles.first ?? .ancha)

                var exito = false

                if let dispositivo = AVCaptureDevice.default(
                    inicial.tipo, for: .video, position: .back
                ), let entrada = try? AVCaptureDeviceInput(device: dispositivo),
                   sesion.canAddInput(entrada) {
                    sesion.addInput(entrada)
                    self.entrada = entrada
                    self.dispositivo = dispositivo
                    self.ajustarEnfoqueInicial(dispositivo)
                    exito = true
                }

                sesion.commitConfiguration()
                self.configurada = exito

                DispatchQueue.main.async {
                    self.lentes = disponibles
                    self.lente = inicial
                }
                continuacion.resume(returning: exito)
            }
        }
    }
}
