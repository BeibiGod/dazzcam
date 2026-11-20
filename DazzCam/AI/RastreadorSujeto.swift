import Accelerate
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
    private var cuadrosEstetica = 0
    private var revisionesMalas = 0
    private var ultimaCaja: CGRect?
    private var ultimaCara = false
    private var generacion = 0
    private var ultimaDeteccion: CFAbsoluteTime = 0
    private var ultimaVezVisto: CFAbsoluteTime = 0
    private var ultimaClasificacion: CFAbsoluteTime = 0

    private var ocupado = false
    private var ultimo: CFAbsoluteTime = 0

    /// Frame chico reutilizado para Vision (evita crear memoria cada cuadro).
    private var bufferChico: CVPixelBuffer?
    private var tamanoChico: (ancho: Int, alto: Int)?

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
            self.cuadrosEstetica = 0
            self.revisionesMalas = 0
            self.ultimaCaja = nil
            self.ultimaCara = false
            self.ultimaDeteccion = 0
            self.ultimaVezVisto = 0
            self.ultimaClasificacion = 0

            self.cerrojo.lock()
            self.ocupado = false
            self.ultimo = 0
            self.cerrojo.unlock()
        }
    }

    /// Suelta la peticion de Vision pero deja la caja en pantalla, para que al
    /// cambiar el zoom la guia no parpadee. La caja se reescala como si la
    /// imagen se hubiera ampliado alrededor del centro.
    func reenganchar(zoom factor: CGFloat) {
        guard factor > 0.01 else { return }

        let ampliada: (CGRect) -> CGRect = { caja in
            CGRect(
                x: (caja.minX - 0.5) * factor + 0.5,
                y: (caja.minY - 0.5) * factor + 0.5,
                width: caja.width * factor,
                height: caja.height * factor
            )
        }

        if let actual = caja {
            caja = ampliada(actual)
        }

        cerrojo.lock()
        generacion &+= 1
        cerrojo.unlock()

        cola.async { [weak self] in
            guard let self else { return }
            self.peticion = nil
            self.perdidos = 0
            self.cuadrosSeguidos = 0
            self.cuadrosEstetica = 0
            self.revisionesMalas = 0
            self.ultimaDeteccion = 0

            if let anterior = self.ultimaCaja {
                self.ultimaCaja = ampliada(anterior)
            }

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

            // Vision sobre un frame chico: vuela y deja de costar tanto.
            let chico = self.reducir(buffer, ancho: 480)
            let resultado = self.procesar(chico ?? buffer)

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

    /// Encoge el frame a ~480 px de ancho antes de Vision. Las cajas siguen
    /// siendo normalizadas (0 a 1), asi que no hay que convertir nada.
    private func reducir(_ buffer: CVPixelBuffer, ancho: Int) -> CVPixelBuffer? {
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        guard w > ancho, h > 0 else { return buffer }

        let alto = max(Int((Double(ancho) * Double(h) / Double(w)).rounded()), 1)

        let destino: CVPixelBuffer

        if let actual = bufferChico,
           let tam = tamanoChico,
           tam.ancho == ancho,
           tam.alto == alto {
            destino = actual
        } else {
            var nuevo: CVPixelBuffer?
            let atributos: [CFString: Any] = [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ]
            guard CVPixelBufferCreate(
                kCFAllocatorDefault,
                ancho,
                alto,
                kCVPixelFormatType_32BGRA,
                atributos as CFDictionary,
                &nuevo
            ) == kCVReturnSuccess, let creado = nuevo else {
                return nil
            }
            bufferChico = creado
            tamanoChico = (ancho, alto)
            destino = creado
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        CVPixelBufferLockBaseAddress(destino, [])
        defer {
            CVPixelBufferUnlockBaseAddress(destino, [])
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }

        guard let origenDatos = CVPixelBufferGetBaseAddress(buffer),
              let destinoDatos = CVPixelBufferGetBaseAddress(destino) else {
            return nil
        }

        var origen = vImage_Buffer(
            data: origenDatos,
            height: vImagePixelCount(h),
            width: vImagePixelCount(w),
            rowBytes: CVPixelBufferGetBytesPerRow(buffer)
        )
        var reducido = vImage_Buffer(
            data: destinoDatos,
            height: vImagePixelCount(alto),
            width: vImagePixelCount(ancho),
            rowBytes: CVPixelBufferGetBytesPerRow(destino)
        )

        guard vImageScale_ARGB8888(&origen, &reducido, nil, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }

        return destino
    }

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
                if cuadrosSeguidos >= 120 {
                    cuadrosSeguidos = 0
                    if let corregido = corregirDeriva(buffer, actual: observacion.boundingBox) {
                        peticion.inputObservation = corregido.objeto
                        ultimaCara = corregido.esCara
                        return publicar(corregido.objeto.boundingBox, esCara: corregido.esCara)
                    }
                }

                // Cada ~8 segundos revisa que el sujeto no sea algo feo
                // (pared, mesa, texto) y, si lo es, se cambia a algo mejor.
                cuadrosEstetica += 1
                if cuadrosEstetica >= 192 {
                    cuadrosEstetica = 0
                    if let bonito = revisarSujeto(buffer, actual: observacion.boundingBox) {
                        return bonito
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
                        cuadrosEstetica = 0
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
        cuadrosEstetica = 0
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
        let manejador = VNImageRequestHandler(
            cvPixelBuffer: buffer,
            orientation: .up,
            options: [:]
        )

        // Primero lo barato: caras y personas. Casi siempre alcanza.
        let caras = VNDetectFaceRectanglesRequest()
        let personas = VNDetectHumanRectanglesRequest()

        if (try? manejador.perform([caras, personas])) != nil {
            // Si ya seguimos algo, no saltar a una cara que anda lejos.
            let cerca: (CGRect) -> Bool = { caja in
                guard let anterior = self.ultimaCaja else { return true }
                let d = hypot(caja.midX - anterior.midX, caja.midY - (1 - anterior.midY))
                return d < 0.45
            }

            let carasCerca = (caras.results ?? [])
                .map { $0 as VNDetectedObjectObservation }
                .filter { cerca($0.boundingBox) }
            if let cara = mejor(carasCerca, preferido: ultimaCaja) {
                return (cara, true)
            }

            let personasCerca = (personas.results ?? [])
                .map { $0 as VNDetectedObjectObservation }
                .filter { cerca($0.boundingBox) }
            if let persona = mejor(personasCerca, preferido: ultimaCaja) {
                return (persona, false)
            }
        }

        // Sin gente: juntar objetos candidatos y quedarse con el mas aesthetic.
        let objetosReq = VNGenerateObjectnessBasedSaliencyImageRequest()
        let atencion = VNGenerateAttentionBasedSaliencyImageRequest()

        guard (try? manejador.perform([objetosReq, atencion])) != nil else {
            return nil
        }

        let objetos = ((objetosReq.results?.first as? VNSaliencyImageObservation)?
            .salientObjects ?? []).filter { area($0.boundingBox) > 0.008 }
        let atentos = ((atencion.results?.first as? VNSaliencyImageObservation)?
            .salientObjects ?? []).filter { area($0.boundingBox) > 0.012 }

        struct Candidato {
            let objeto: VNDetectedObjectObservation
            let definido: Bool
        }

        var candidatos: [Candidato] = objetos.map { Candidato(objeto: $0, definido: true) }
        candidatos += atentos.map { Candidato(objeto: $0, definido: false) }

        guard !candidatos.isEmpty else { return nil }

        // Los 2 mejores por forma/tamano/centro; entre ellos, gana el que
        // se vea mas aesthetic (comida, plantas, arquitectura, arte...).
        let ordenados = candidatos.sorted {
            puntajeForma($0.objeto, definido: $0.definido)
                > puntajeForma($1.objeto, definido: $1.definido)
        }
        let finalistas = Array(ordenados.prefix(2))

        let ahora = CFAbsoluteTimeGetCurrent()
        let puedeClasificar = ahora - ultimaClasificacion >= 1.2
        if puedeClasificar {
            ultimaClasificacion = ahora
        }

        // Si ya hay un sujeto, mandan la cercania y la continuidad: lo
        // aesthetic solo decide cuando se elige de cero.
        let pesoEstetica: CGFloat = ultimaCaja == nil ? 1.0 : 0.45

        var elegido = finalistas[0]
        var mejorPuntaje = -CGFloat.infinity

        for candidato in finalistas {
            var puntos = puntajeForma(candidato.objeto, definido: candidato.definido)

            // Si ya seguiamos algo, no saltar lejos de ahi.
            if let anterior = ultimaCaja {
                let c = CGPoint(x: candidato.objeto.boundingBox.midX, y: candidato.objeto.boundingBox.midY)
                let dist = hypot(c.x - anterior.midX, c.y - (1 - anterior.midY))
                puntos -= min(dist, 1) * 1.0
            }

            if puedeClasificar {
                puntos += bonusEstetico(
                    candidato.objeto.boundingBox,
                    manejador: manejador
                ) * pesoEstetica
            }

            if puntos > mejorPuntaje {
                mejorPuntaje = puntos
                elegido = candidato
            }
        }

        return (elegido.objeto, false)
    }

    /// Elige la mejor deteccion: si ya seguiamos algo, prefiere la que queda
    /// cerca de donde iba para no saltar a otro sujeto.
    private func mejor(
        _ observaciones: [VNDetectedObjectObservation],
        preferido: CGRect?
    ) -> VNDetectedObjectObservation? {
        guard !observaciones.isEmpty else { return nil }

        if let preferido {
            let centro = CGPoint(x: preferido.midX, y: 1 - preferido.midY)

            return observaciones.max { a, b in
                puntajeCerca(a, centro: centro, anterior: preferido)
                    < puntajeCerca(b, centro: centro, anterior: preferido)
            }
        }

        return observaciones.max(by: { area($0.boundingBox) < area($1.boundingBox) })
    }

    /// Para caras y personas: cerca y de tamano parecido gana.
    private func puntajeCerca(
        _ obs: VNDetectedObjectObservation,
        centro: CGPoint,
        anterior: CGRect
    ) -> CGFloat {
        let caja = obs.boundingBox
        let c = CGPoint(x: caja.midX, y: caja.midY)
        let dist = hypot(c.x - centro.x, c.y - centro.y)
        let tam = area(caja)
        let tamAnterior = max(anterior.width * anterior.height, 0.001)
        let parecido = 1 - min(abs(tam - tamAnterior) / tamAnterior, 1)

        return (1 - min(dist, 1)) * 1.4 + parecido * 0.4 + min(tam * 4, 1) * 0.2
    }

    /// Forma/tamano/posicion: prefiere cosas completas, centradas y de buen
    /// tamano; castiga parches en el borde y tiras raras.
    private func puntajeForma(
        _ obs: VNDetectedObjectObservation,
        definido: Bool
    ) -> CGFloat {
        let caja = obs.boundingBox
        let c = CGPoint(x: caja.midX, y: caja.midY)
        let tam = area(caja)

        let central = 1 - min(hypot(c.x - 0.5, c.y - 0.5) * 1.3, 1)

        let tamBueno: CGFloat
        if tam < 0.02 {
            tamBueno = tam * 8
        } else if tam > 0.55 {
            tamBueno = 0.55 / tam
        } else {
            tamBueno = 0.7 + tam
        }

        // Una caja pegada al borde suele ser pared, mesa o piso.
        let tocaBorde: CGFloat =
            (caja.minX < 0.03 || caja.maxX > 0.97 || caja.minY < 0.03 || caja.maxY > 0.97)
            ? 0.35
            : 1.0

        let ratio = caja.width / max(caja.height, 0.001)
        let forma: CGFloat = (ratio > 0.35 && ratio < 2.8) ? 1.0 : 0.6

        let tipo: CGFloat = definido ? 1.15 : 1.0

        return (tamBueno * 0.9 + central * 0.9) * tocaBorde * forma * tipo
    }

    /// Suma puntos si lo que hay dentro de la caja se ve aesthetic.
    private func bonusEstetico(
        _ caja: CGRect,
        manejador: VNImageRequestHandler
    ) -> CGFloat {
        let clasificar = VNClassifyImageRequest()
        clasificar.regionOfInterest = caja

        guard (try? manejador.perform([clasificar])) != nil else { return 0 }

        var bueno: CGFloat = 0
        var malo: CGFloat = 0

        // Se miran bastantes etiquetas: la buena suele venir mas abajo que
        // las cuatro primeras (que casi siempre son "wall", "indoor"...).
        for etiqueta in (clasificar.results ?? []).prefix(25) {
            let id = etiqueta.identifier
                .replacingOccurrences(of: "_", with: " ")
                .lowercased()
            let palabras = Set(id.split(separator: " ").map(String.init))
            let confianza = CGFloat(etiqueta.confidence)

            if !palabras.isDisjoint(with: Self.buenas) {
                bueno = max(bueno, confianza)
            } else if !palabras.isDisjoint(with: Self.malas) {
                malo = max(malo, confianza)
            }
        }

        return bueno * 1.8 - malo * 1.1
    }

    /// Cada tanto revisa que lo que estamos siguiendo no sea una pared, una
    /// mesa o texto. Si salio feo dos veces seguidas y hay algo claramente
    /// mejor, se cambia. Nunca cambia por cambiar.
    private func revisarSujeto(
        _ buffer: CVPixelBuffer,
        actual: CGRect
    ) -> Resultado? {
        let manejador = VNImageRequestHandler(
            cvPixelBuffer: buffer,
            orientation: .up,
            options: [:]
        )

        let puntos = bonusEstetico(actual, manejador: manejador)

        guard puntos <= -0.3 else {
            revisionesMalas = 0
            return nil
        }

        revisionesMalas += 1
        guard revisionesMalas >= 2 else { return nil }

        // Que la deteccion pueda clasificar sin esperar el turno.
        ultimaClasificacion = 0
        guard let encontrado = detectar(buffer) else { return nil }

        let nuevo = encontrado.objeto.boundingBox
        let dist = hypot(nuevo.midX - actual.midX, nuevo.midY - actual.midY)

        // Otro sitio y claramente mas lindo, o no vale la pena el salto.
        guard dist > 0.06 else { return nil }
        let nuevosPuntos = bonusEstetico(nuevo, manejador: manejador)
        guard nuevosPuntos >= puntos + 0.5 else { return nil }

        revisionesMalas = 0
        ultimaCara = encontrado.esCara
        ultimaVezVisto = CFAbsoluteTimeGetCurrent()

        let nueva = VNTrackObjectRequest(detectedObjectObservation: encontrado.objeto)
        nueva.trackingLevel = .accurate
        peticion = nueva

        return publicar(nuevo, esCara: encontrado.esCara)
    }

    /// Lo que se ve lindo en una foto (palabras exactas de Vision).
    private static let buenas: Set<String> = [
        "person", "people", "portrait", "face", "selfie", "smile", "family",
        "baby", "child", "kid", "man", "woman", "bride", "groom",
        "pet", "dog", "puppy", "cat", "kitten", "animal", "bird", "horse",
        "flower", "flowers", "blossom", "bouquet", "plant", "houseplant",
        "succulent", "foliage", "tree", "forest", "garden", "park",
        "food", "meal", "dish", "cuisine", "dessert", "cake", "bread",
        "bakery", "pizza", "sushi", "seafood", "fruit", "produce",
        "vegetable", "coffee", "drink", "beverage", "cocktail", "wine",
        "sky", "cloud", "clouds", "sunset", "sunrise", "landscape",
        "beach", "coast", "sea", "ocean", "lake", "river", "waterfall",
        "mountain", "snow", "desert", "island", "harbor", "water",
        "architecture", "building", "house", "church", "castle", "bridge",
        "skyscraper", "tower", "monument", "statue", "sculpture", "museum",
        "street", "city", "downtown", "alley", "art", "artwork", "painting",
        "graffiti", "vehicle", "car", "motorcycle", "bicycle", "boat",
        "train", "airplane", "fashion", "jewelry", "footwear", "book",
        "guitar", "instrument", "stage", "concert", "fireworks"
    ]

    /// Lo que suele quedar feo como sujeto.
    private static let malas: Set<String> = [
        "text", "document", "receipt", "screenshot", "wall", "ceiling",
        "floor", "carpet", "pattern", "paper", "keyboard", "whiteboard",
        "blank", "plastic", "cardboard", "trash", "garbage", "wire", "cable",
        "metal", "concrete", "asphalt", "tile", "curtain", "blinds"
    ]

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
            let salto = hypot(nueva.midX - anterior.midX, nueva.midY - anterior.midY)

            if salto > 0.3 {
                // Otro sujeto: mejor saltar directo que arrastrar el recuadro
                // por toda la pantalla.
                suave = nueva
            } else {
                // Posicion responde rapido, tamano cambia mas suave para evitar temblor.
                let pesoPos: CGFloat = 0.58
                let pesoTam: CGFloat = 0.35
                suave = CGRect(
                    x: anterior.minX + (nueva.minX - anterior.minX) * pesoPos,
                    y: anterior.minY + (nueva.minY - anterior.minY) * pesoPos,
                    width: anterior.width + (nueva.width - anterior.width) * pesoTam,
                    height: anterior.height + (nueva.height - anterior.height) * pesoTam
                )
            }
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
