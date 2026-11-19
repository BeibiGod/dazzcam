import Combine
import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Sigue al sujeto cuadro a cuadro, como el aimbot de Framed. La IA lo
/// engancha una vez (una cara o lo que mas llama la atencion) y despues
/// Vision lo persigue en cada frame del visor. Asi el recuadro se mueve con
/// la camara en vez de quedarse donde empezo.
final class RastreadorSujeto: ObservableObject {

    /// Caja del sujeto, de 0 a 1, con el origen arriba a la izquierda.
    @Published private(set) var caja: CGRect?
    /// true cuando lo que se sigue es una cara: se dibuja cabeza y hombros.
    @Published private(set) var esCara = false
    /// true mientras busca un sujeto nuevo despues de perderlo.
    @Published private(set) var buscando = false

    /// Lo prende la vista cuando la guia esta abierta.
    var activo = false

    private struct Resultado {
        let caja: CGRect
        let esCara: Bool
    }

    private let cola = DispatchQueue(label: "com.diego.dazzcam.rastreo", qos: .userInitiated)
    private let cerrojo = NSLock()
    private let secuencia = VNSequenceRequestHandler()

    private var peticion: VNTrackObjectRequest?
    private var perdidos = 0
    private var ultimaCaja: CGRect?
    private var ultimaCara = false
    private var generacion = 0

    private var ocupado = false
    private var ultimo: CFAbsoluteTime = 0

    /// Unos 24 cuadros por segundo: se siente pegado a la mano y no gasta
    /// bateria de mas.
    private let intervalo: CFAbsoluteTime = 1.0 / 24.0

    // MARK: - Encendido

    func empezar() {
        activo = true
        buscando = true

        cerrojo.lock()
        generacion &+= 1
        cerrojo.unlock()

        cola.async { [weak self] in
            guard let self else { return }
            self.peticion = nil
            self.perdidos = 0
            self.ultimaCaja = nil
            self.ultimaCara = false

            self.cerrojo.lock()
            self.ocupado = false
            self.ultimo = 0
            self.cerrojo.unlock()
        }
    }

    func parar() {
        activo = false
        caja = nil
        buscando = false

        cerrojo.lock()
        generacion &+= 1
        cerrojo.unlock()

        cola.async { [weak self] in
            guard let self else { return }
            self.peticion = nil
            self.ultimaCaja = nil

            self.cerrojo.lock()
            self.ocupado = false
            self.cerrojo.unlock()
        }
    }

    // MARK: - Cada cuadro

    /// La llama la salida de video con el frame crudo. Se salta cuadros para
    /// no competir con el filtro del visor.
    func mirar(_ buffer: CVPixelBuffer) {
        guard activo else { return }

        let ahora = CFAbsoluteTimeGetCurrent()

        cerrojo.lock()
        guard !ocupado, ahora - ultimo >= intervalo else {
            cerrojo.unlock()
            return
        }
        ocupado = true
        ultimo = ahora
        let actual = generacion
        cerrojo.unlock()

        cola.async { [weak self] in
            guard let self else { return }

            let resultado = self.procesar(buffer)

            self.cerrojo.lock()
            self.ocupado = false
            let sigue = self.generacion == actual
            self.cerrojo.unlock()

            DispatchQueue.main.async {
                guard self.activo, sigue else { return }

                if let resultado {
                    self.caja = resultado.caja
                    self.esCara = resultado.esCara
                    self.buscando = false
                } else {
                    self.buscando = true
                }
            }
        }
    }

    // MARK: - Seguimiento

    private func procesar(_ buffer: CVPixelBuffer) -> Resultado? {
        if let peticion {
            do {
                try secuencia.perform([peticion], on: buffer, orientation: .up)
            } catch {
                self.peticion = nil
            }

            if let observacion = peticion.results?.first as? VNDetectedObjectObservation,
               observacion.confidence >= 0.3 {
                peticion.inputObservation = observacion
                perdidos = 0
                return publicar(observacion.boundingBox, esCara: ultimaCara)
            }

            perdidos += 1

            // Un par de cuadros malos no borran la caja: se queda quieta
            // mientras Vision se recupera.
            if perdidos < 6, let ultimaCaja {
                return Resultado(caja: ultimaCaja, esCara: ultimaCara)
            }

            self.peticion = nil
        }

        // Se perdio: se busca otra vez, cara primero y despues lo que mas
        // llama la atencion en el cuadro.
        guard let encontrado = detectar(buffer) else {
            perdidos += 1
            return nil
        }

        perdidos = 0
        ultimaCara = encontrado.esCara

        let nueva = VNTrackObjectRequest(detectedObjectObservation: encontrado.objeto)
        nueva.trackingLevel = .fast
        peticion = nueva

        return publicar(encontrado.objeto.boundingBox, esCara: encontrado.esCara)
    }

    private func detectar(
        _ buffer: CVPixelBuffer
    ) -> (objeto: VNDetectedObjectObservation, esCara: Bool)? {
        let caras = VNDetectFaceRectanglesRequest()
        let saliencia = VNGenerateAttentionBasedSaliencyImageRequest()
        let manejador = VNImageRequestHandler(
            cvPixelBuffer: buffer,
            orientation: .up,
            options: [:]
        )

        do {
            try manejador.perform([caras, saliencia])
        } catch {
            return nil
        }

        if let cara = (caras.results ?? []).max(by: {
            area($0.boundingBox) < area($1.boundingBox)
        }) {
            return (cara, true)
        }

        let objetos = (saliencia.results?.first as? VNSaliencyImageObservation)?
            .salientObjects ?? []

        guard let mayor = objetos.max(by: {
            area($0.boundingBox) < area($1.boundingBox)
        }) else {
            return nil
        }

        return (mayor, false)
    }

    /// Pasa la caja a coordenadas de pantalla y la suaviza para que no tiemble.
    private func publicar(_ cajaVision: CGRect, esCara: Bool) -> Resultado {
        let nueva = CGRect(
            x: cajaVision.minX,
            y: 1 - cajaVision.maxY,
            width: cajaVision.width,
            height: cajaVision.height
        )

        let suave: CGRect

        if let anterior = ultimaCaja, anterior.width > 0.001 {
            let peso: CGFloat = 0.45
            suave = CGRect(
                x: anterior.minX + (nueva.minX - anterior.minX) * peso,
                y: anterior.minY + (nueva.minY - anterior.minY) * peso,
                width: anterior.width + (nueva.width - anterior.width) * peso,
                height: anterior.height + (nueva.height - anterior.height) * peso
            )
        } else {
            suave = nueva
        }

        ultimaCaja = suave
        ultimaCara = esCara

        return Resultado(caja: suave, esCara: esCara)
    }

    private func area(_ caja: CGRect) -> CGFloat {
        caja.width * caja.height
    }
}
