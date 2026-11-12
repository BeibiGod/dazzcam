import AVFoundation
import Combine

/// Distancias focales del iPhone, como las muestra la app de camara.
enum Lente: String, CaseIterable, Identifiable {
    case ultra = "0.5"
    case ancha = "1"
    case tele = "3"

    var id: String { rawValue }

    var etiqueta: String { rawValue + "x" }

    /// Factor de zoom que representa.
    var factor: CGFloat {
        switch self {
        case .ultra: return 0.5
        case .ancha: return 1
        case .tele: return 3
        }
    }

    var tipo: AVCaptureDevice.DeviceType {
        switch self {
        case .ultra: return .builtInUltraWideCamera
        case .ancha: return .builtInWideAngleCamera
        case .tele: return .builtInTelephotoCamera
        }
    }
}

/// Maneja la camara. Usa el dispositivo virtual (ultra + principal + tele)
/// para que el zoom sea continuo, igual que en la app de Apple.
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
    @Published private(set) var lentes: [Lente] = []
    @Published private(set) var zoom: CGFloat = 1
    @Published private(set) var tieneFlash = false

    let session = AVCaptureSession()

    private let cola = DispatchQueue(label: "com.diego.dazzcam.camara")
    private var configurada = false
    private var arrancada = false
    private var entrada: AVCaptureDeviceInput?
    private var dispositivo: AVCaptureDevice?

    /// Cuanto vale 1.0 de videoZoomFactor en "x" de pantalla.
    /// En la camara triple, 1.0 es el ultra gran angular (0.5x).
    private var baseZoom: CGFloat = 1

    /// Tope de zoom mostrado.
    private let zoomMaximo: CGFloat = 8

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

    // MARK: - Zoom

    /// Salta a una distancia focal concreta (0.5x, 1x, 3x).
    func irA(_ lente: Lente) {
        ponerZoom(lente.factor)
    }

    /// Pone el zoom en "x" de pantalla. Ej: 2.4 significa 2.4x.
    func ponerZoom(_ factor: CGFloat) {
        guard let dispositivo = dispositivo else { return }

        let video = factor / baseZoom
        let topeVideo = min(zoomMaximo / baseZoom, dispositivo.activeFormat.videoMaxZoomFactor)
        let valor = min(max(video, 1), topeVideo)

        do {
            try dispositivo.lockForConfiguration()
            dispositivo.videoZoomFactor = valor
            dispositivo.unlockForConfiguration()
            zoom = valor * baseZoom
        } catch {
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
        }
    }

    /// Compensacion de exposicion en pasos EV.
    func fijarExposicion(_ ev: Float) {
        guard let dispositivo = dispositivo else { return }

        let valor = min(max(ev, dispositivo.minExposureTargetBias), dispositivo.maxExposureTargetBias)

        do {
            try dispositivo.lockForConfiguration()
            dispositivo.setExposureTargetBias(valor, completionHandler: nil)
            dispositivo.unlockForConfiguration()
        } catch {
        }
    }

    private nonisolated func ajustarInicial(_ dispositivo: AVCaptureDevice) {
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

        return await withCheckedContinuation { (continuacion: CheckedContinuation<Bool, Never>) in
            cola.async {
                let sesion = self.session
                sesion.beginConfiguration()
                sesion.sessionPreset = .photo

                // La camara virtual cambia de lente sola al hacer zoom.
                let tipos: [AVCaptureDevice.DeviceType] = [
                    .builtInTripleCamera,
                    .builtInDualWideCamera,
                    .builtInWideAngleCamera
                ]

                var dispositivo: AVCaptureDevice?
                for tipo in tipos {
                    if let encontrado = AVCaptureDevice.default(tipo, for: .video, position: .back) {
                        dispositivo = encontrado
                        break
                    }
                }

                var exito = false
                var base: CGFloat = 1
                var lista: [Lente] = []

                if let dispositivo = dispositivo,
                   let entrada = try? AVCaptureDeviceInput(device: dispositivo),
                   sesion.canAddInput(entrada) {

                    sesion.addInput(entrada)
                    self.entrada = entrada
                    self.dispositivo = dispositivo
                    self.ajustarInicial(dispositivo)

                    // En la camara virtual triple, 1.0 de zoom equivale al
                    // ultra gran angular, o sea 0.5x en pantalla.
                    let esVirtual = dispositivo.deviceType == .builtInTripleCamera
                        || dispositivo.deviceType == .builtInDualWideCamera
                    base = esVirtual ? 0.5 : 1
                    self.baseZoom = base

                    let hayUltra = esVirtual
                        || AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
                    let hayTele = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) != nil

                    if hayUltra { lista.append(.ultra) }
                    lista.append(.ancha)
                    if hayTele { lista.append(.tele) }

                    exito = true
                }

                sesion.commitConfiguration()
                self.configurada = exito

                DispatchQueue.main.async {
                    self.lentes = lista
                    self.zoom = base
                    self.tieneFlash = self.dispositivo?.hasFlash ?? false
                }
                continuacion.resume(returning: exito)
            }
        }
    }
}
