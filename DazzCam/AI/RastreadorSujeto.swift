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
    private var cuadrosSeguidos = 0
    private var ultimaCaja: CGRect?
    private var ultimaCara = false
    private var generacion = 0
    private var ultimaDeteccion: CFAbsoluteTime = 0
    private var ultimaVezVisto: CFAbsoluteTime = 0

    private var ocupado = false
    private var ultimo: CFAbsoluteTime = 0

    /// Rapido para que el recuadro se sienta pegado al sujeto.
    private let intervalo: CFAbsoluteTime = 1.0 / 24.0

    // MARK: - Encendido

    func empezar() {
        activo = true
        caja = nil
        esCara = false
        buscando = true

        cerrojo.lock()
        generacion &+= 1
        cerrojo.unlock()

        cola.async { [weak self] in
            guard let self else { return }
            self.peticion = nil
            self.perdidos = 0
            self.cuadrosSeguidos = 0
            self.ultimaCaja = nil
            self.ultimaCara = false
            self.ultimaDeteccion = 0
            self.ultimaVezVisto = 0

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
                    self.caja = nil
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
               observacion.confidence >= 0.25 {
                peticion.inputObservation = observacion
                perdidos = 0
                cuadrosSeguidos += 1
                ultimaVezVisto = CFAbsoluteTimeGetCurrent()

                // Corrige deriva cada cierto tiempo, pero solo si la deteccion
                // sigue cerca del sujeto que ya estamos siguiendo.
                if cuadrosSeguidos >= 60 {
                    cuadrosSeguidos = 0
                    if let corregido = corregirDeriva(buffer, actual: observacion.boundingBox) {
                        peticion.inputObservation = corregido.objeto
                        ultimaCara = corregido.esCara
                        return publicar(corregido.objeto.boundingBox, esCara: corregido.esCara)
                    }
                }

                return publicar(observacion.boundingBox, esCara: ultimaCara)
            }

            perdidos += 1

            // Si falla varias veces seguidas, intenta re-detectar antes de rendirse.
            if perdidos >= 3 && perdidos < 10 {
                let ahora = CFAbsoluteTimeGetCurrent()
                if ahora - ultimaDeteccion >= 0.45, let encontrado = detectar(buffer) {
                    ultimaDeteccion = ahora
                    let dist = hypot(
                        encontrado.objeto.boundingBox.midX - (ultimaCaja.map { $0.midX } ?? encontrado.objeto.boundingBox.midX),
                        encontrado.objeto.boundingBox.midY - (ultimaCaja.map { 1 - $0.midY } ?? encontrado.objeto.boundingBox.midY)
                    )
                    if ultimaCaja == nil || dist < 0.25 {
                        perdidos = 0
                        cuadrosSeguidos = 0
                        ultimaCara = encontrado.esCara
                        ultimaVezVisto = ahora
                        let nueva = VNTrackObjectRequest(detectedObjectObservation: encontrado.objeto)
                        nueva.trackingLevel = .accurate
                        self.peticion = nueva
                        return publicar(encontrado.objeto.boundingBox, esCara: encontrado.esCara)
                    }
                }
            }

            // Unos cuadros malos no borran la caja: se queda quieta mientras
            // Vision se recupera.
            if perdidos < 10, let ultimaCaja {
                return Resultado(caja: ultimaCaja, esCara: ultimaCara)
            }

            self.peticion = nil
        }

        // Se perdio: busca de nuevo, sin hacerlo a cada instante.
        let ahora = CFAbsoluteTimeGetCurrent()
        guard ahora - ultimaDeteccion >= 0.35 else {
            if let ultimaCaja, ahora - ultimaVezVisto < 2.0 {
                return Resultado(caja: ultimaCaja, esCara: ultimaCara)
            }
            ultimaCaja = nil
            return nil
        }
        ultimaDeteccion = ahora

        guard let encontrado = detectar(buffer) else {
            if ultimaVezVisto == 0 || ahora - ultimaVezVisto > 2.0 {
                ultimaCaja = nil
                return nil
            }
            if let ultimaCaja {
                return Resultado(caja: ultimaCaja, esCara: ultimaCara)
            }
            return nil
        }

        perdidos = 0
        cuadrosSeguidos = 0
        ultimaCara = encontrado.esCara
        ultimaVezVisto = ahora

        let nueva = VNTrackObjectRequest(detectedObjectObservation: encontrado.objeto)
        nueva.trackingLevel = .accurate
        peticion = nueva

        return publicar(encontrado.objeto.boundingBox, esCara: encontrado.esCara)
    }

    /// Re-detecta para corregir la deriva del tracker, pero solo acepta si
    /// la deteccion sigue cerca de lo que ya se estaba siguiendo.
    private func corregirDeriva(
        _ buffer: CVPixelBuffer,
        actual: CGRect
    ) -> (objeto: VNDetectedObjectObservation, esCara: Bool)? {
        guard let encontrado = detectar(buffer) else { return nil }

        let c1 = CGPoint(x: actual.midX, y: actual.midY)
        let c2 = CGPoint(x: encontrado.objeto.boundingBox.midX, y: encontrado.objeto.boundingBox.midY)
        let dist = hypot(c1.x - c2.x, c1.y - c2.y)

        // Si la deteccion fresca esta cerca, la usamos para anclar el tracker.
        guard dist < 0.18 else { return nil }
        return encontrado
    }

    private func detectar(
        _ buffer: CVPixelBuffer
    ) -> (objeto: VNDetectedObjectObservation, esCara: Bool)? {
        let caras = VNDetectFaceRectanglesRequest()
        let personas = VNDetectHumanRectanglesRequest()
        let atencion = VNGenerateAttentionBasedSaliencyImageRequest()
        let objetosReq = VNGenerateObjectnessBasedSaliencyImageRequest()
        let manejador = VNImageRequestHandler(
            cvPixelBuffer: buffer,
            orientation: .up,
            options: [:]
        )

        do {
            try manejador.perform([caras, personas, atencion, objetosReq])
        } catch {
            return nil
        }

        // Cara = sujeto mas claro (retrato).
        if let cara = mejor(caras.results ?? [], preferido: nil) {
            return (cara, true)
        }

        // Persona completa.
        if let persona = mejor(personas.results ?? [], preferido: ultimaCaja) {
            return (persona, false)
        }

        // Objetos definidos (suelen ser cosas concretas como laptop, taza, etc).
        let objetos = ((objetosReq.results?.first as? VNSaliencyImageObservation)?
            .salientObjects ?? []).filter { area($0.boundingBox) > 0.008 }
        if let objeto = mejorObjeto(objetos, preferido: ultimaCaja) {
            return (objeto, false)
        }

        // Fallback: lo que mas llama la atencion.
        let atentos = ((atencion.results?.first as? VNSaliencyImageObservation)?
            .salientObjects ?? []).filter { area($0.boundingBox) > 0.012 }
        if let objeto = mejorObjeto(atentos, preferido: ultimaCaja) {
            return (objeto, false)
        }

        return nil
    }

    /// Elige la mejor deteccion: si ya seguiamos algo, prefiere la que queda
    /// cerca de donde iba para no saltar a otro sujeto.
    private func mejor(
        _ observaciones: [VNDetectedObjectObservation],
        preferido: CGRect?
    ) -> VNDetectedObjectObservation? {
        guard !observaciones.isEmpty else { return nil }

        if let preferido = preferido {
            let centro = CGPoint(x: preferido.midX, y: 1 - preferido.midY)

            return observaciones.max { a, b in
                puntaje(a, cercaDe: centro, anterior: preferido)
                    < puntaje(b, cercaDe: centro, anterior: preferido)
            }
        }

        return observaciones.max(by: { area($0.boundingBox) < area($1.boundingBox) })
    }

    /// Para objetos/saliencia: prefiere sujetos centrados y de tamano razonable,
    /// no parches chicos en una esquina.
    private func mejorObjeto(
        _ observaciones: [VNDetectedObjectObservation],
        preferido: CGRect?
    ) -> VNDetectedObjectObservation? {
        guard !observaciones.isEmpty else { return nil }

        let centroImagen = CGPoint(x: 0.5, y: 0.5)

        if let preferido = preferido {
            let centro = CGPoint(x: preferido.midX, y: 1 - preferido.midY)
            return observaciones.max { a, b in
                puntajeObjeto(a, cercaDe: centro, anterior: preferido, centroImagen: centroImagen)
                    < puntajeObjeto(b, cercaDe: centro, anterior: preferido, centroImagen: centroImagen)
            }
        }

        return observaciones.max { a, b in
            puntajeObjetoNuevo(a, centroImagen: centroImagen)
                < puntajeObjetoNuevo(b, centroImagen: centroImagen)
        }
    }

    private func puntajeObjeto(
        _ obs: VNDetectedObjectObservation,
        cercaDe centro: CGPoint,
        anterior: CGRect,
        centroImagen: CGPoint
    ) -> CGFloat {
        let caja = obs.boundingBox
        let c = CGPoint(x: caja.midX, y: caja.midY)
        let dist = hypot(c.x - centro.x, c.y - centro.y)
        let tam = area(caja)
        let tamAnterior = max(areaVision(anterior), 0.001)
        let parecido = 1 - min(abs(tam - tamAnterior) / tamAnterior, 1)
        let central = 1 - min(hypot(c.x - centroImagen.x, c.y - centroImagen.y), 1)

        return (1 - min(dist, 1)) * 1.6 + parecido * 0.4 + min(tam * 3, 1) * 0.25 + central * 0.15
    }

    private func puntajeObjetoNuevo(_ obs: VNDetectedObjectObservation, centroImagen: CGPoint) -> CGFloat {
        let caja = obs.boundingBox
        let c = CGPoint(x: caja.midX, y: caja.midY)
        let tam = area(caja)
        let central = 1 - min(hypot(c.x - centroImagen.x, c.y - centroImagen.y) * 1.4, 1)
        // Penaliza cosas muy chicas o gigantes (fondo completo).
        let tamBueno = tam > 0.02 && tam < 0.7 ? min(tam * 3.5, 1) : tam * 0.5

        return tamBueno * 0.55 + central * 0.35 + CGFloat(obs.confidence) * 0.1
    }

    private func puntaje(
        _ obs: VNDetectedObjectObservation,
        cercaDe centro: CGPoint,
        anterior: CGRect
    ) -> CGFloat {
        let caja = obs.boundingBox
        let c = CGPoint(x: caja.midX, y: caja.midY)
        let dist = hypot(c.x - centro.x, c.y - centro.y)
        let tam = area(caja)
        let tamAnterior = max(areaVision(anterior), 0.001)
        let parecido = 1 - min(abs(tam - tamAnterior) / tamAnterior, 1)

        // Cerca y de tamano parecido gana; el tamano ayuda a desempatar.
        return (1 - min(dist, 1)) * 1.4 + parecido * 0.4 + min(tam * 4, 1) * 0.2
    }

    private func areaVision(_ cajaTopLeft: CGRect) -> CGFloat {
        cajaTopLeft.width * cajaTopLeft.height
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
            // Posicion responde rapido, tamano cambia mas suave para evitar temblor.
            let pesoPos: CGFloat = 0.58
            let pesoTam: CGFloat = 0.35
            suave = CGRect(
                x: anterior.minX + (nueva.minX - anterior.minX) * pesoPos,
                y: anterior.minY + (nueva.minY - anterior.minY) * pesoPos,
                width: anterior.width + (nueva.width - anterior.width) * pesoTam,
                height: anterior.height + (nueva.height - anterior.height) * pesoTam
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
