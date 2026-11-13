import AVFoundation
import Combine
import UIKit

enum ModoCaptura: String, CaseIterable, Identifiable {
    case foto = "FOTO"
    case video = "VIDEO"

    var id: String { rawValue }
}

/// Graba video con sonido y despues le hornea el look elegido.
@MainActor
final class MovieRecorder: NSObject, ObservableObject {

    @Published private(set) var grabando = false
    @Published private(set) var procesando = false
    @Published private(set) var segundos = 0
    @Published private(set) var error: String?
    @Published private(set) var guardados = 0

    let salida = AVCaptureMovieFileOutput()

    private var sesion: AVCaptureSession?
    private var entradaAudio: AVCaptureDeviceInput?
    private var pausada: AVCaptureVideoDataOutput?
    private var preset: FilterPreset = .dazzClassic
    private var controles = ControlesLook()
    private var reloj: Timer?

    // MARK: - Preparacion

    func conectar(a sesion: AVCaptureSession) {
        guard !sesion.outputs.contains(where: { $0 === salida }) else {
            self.sesion = sesion
            return
        }
        guard sesion.canAddOutput(salida) else {
            error = "No se pudo preparar la grabacion de video"
            return
        }

        sesion.beginConfiguration()
        sesion.addOutput(salida)
        sesion.commitConfiguration()
        self.sesion = sesion
    }

    // MARK: - Grabar

    func empezar(
        preset: FilterPreset,
        controles: ControlesLook = ControlesLook(),
        quitar: AVCaptureVideoDataOutput?
    ) async {
        guard !grabando, !procesando, let sesion = sesion else { return }

        error = nil
        self.preset = preset
        self.controles = controles
        pausada = quitar

        let conMicro = await pedirMicrofono()
        if !conMicro {
            error = "Sin permiso de microfono: el video saldra sin sonido"
        }

        sesion.beginConfiguration()

        if conMicro,
           let micro = AVCaptureDevice.default(for: .audio),
           let entrada = try? AVCaptureDeviceInput(device: micro),
           sesion.canAddInput(entrada) {
            sesion.addInput(entrada)
            entradaAudio = entrada
        }

        // el flujo de video en vivo estorba mientras se graba
        if let quitar = quitar {
            sesion.removeOutput(quitar)
        }

        sesion.commitConfiguration()

        if let conexion = salida.connection(with: .video),
           conexion.isVideoRotationAngleSupported(90) {
            conexion.videoRotationAngle = 90
        }

        let destino = FileManager.default.temporaryDirectory
            .appendingPathComponent("beibi-grabando-\(UUID().uuidString).mov")

        salida.startRecording(to: destino, recordingDelegate: self)

        grabando = true
        segundos = 0
        iniciarReloj()
    }

    func parar() {
        guard grabando else { return }
        grabando = false
        detenerReloj()
        salida.stopRecording()
    }

    // MARK: - Reloj

    private func iniciarReloj() {
        detenerReloj()
        reloj = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.grabando else { return }
                self.segundos += 1
            }
        }
    }

    private func detenerReloj() {
        reloj?.invalidate()
        reloj = nil
    }

    // MARK: - Microfono

    private func pedirMicrofono() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    // MARK: - Devolver la sesion como estaba

    private func devolverSesion() {
        guard let sesion = sesion else { return }

        sesion.beginConfiguration()

        if let entrada = entradaAudio {
            sesion.removeInput(entrada)
            entradaAudio = nil
        }

        if let volver = pausada,
           !sesion.outputs.contains(where: { $0 === volver }),
           sesion.canAddOutput(volver) {
            sesion.addOutput(volver)
        }
        pausada = nil

        sesion.commitConfiguration()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension MovieRecorder: AVCaptureFileOutputRecordingDelegate {

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.terminar(url: outputFileURL, error: error)
        }
    }

    private func terminar(url: URL, error: Error?) {
        grabando = false
        detenerReloj()
        devolverSesion()

        if let error = error {
            let ns = error as NSError
            let terminoBien = ns.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
            if !terminoBien {
                self.error = "Fallo el video: \(error.localizedDescription)"
                return
            }
        }

        let look = preset
        let ajustes = controles
        procesando = true

        Task {
            defer { procesando = false }

            do {
                let conFiltro = try await VideoBaker.exportar(
                    url,
                    preset: look,
                    controles: ajustes
                )
                try await PhotoLibrarySaver.guardarVideo(conFiltro)
                guardados += 1
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: conFiltro)
            } catch {
                self.error = "No se pudo guardar el video: \(error.localizedDescription)"
            }
        }
    }
}
