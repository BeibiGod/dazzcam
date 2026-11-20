import CoreGraphics
import UIKit
import Vision

/// Lo que la IA ve y hacia donde conviene mover el telefono. Va en
/// coordenadas de la foto, de 0 a 1 y desde arriba a la izquierda.
struct Guia {
    /// Caja del sujeto que la IA esta siguiendo.
    var sujeto: CGRect
    /// Cruce de tercios donde conviene dejarlo.
    var destino: CGPoint
    /// true cuando ya esta en el lugar bueno.
    var listo: Bool
    /// Que hacer: "Mueve el telefono a la derecha", "Buen encuadre", etc.
    var instruccion: String
    /// Cuanto acercar (o alejar) el zoom para que el sujeto quede bien.
    /// nil = ya esta bien. Ej: 1.6 = acercar 1.6x.
    var zoom: CGFloat?
}

/// Lo que devuelve el analisis de una escena.
struct Analisis {
    var puntaje: Int
    var resumen: String
    var consejos: [String]
    var etiquetas: [String]
    var caras: Int
    var sugerencias: [FilterPreset]

    /// Medidas reales de la escena, para que se vea que si se analizo.
    var luz: Int          // 0-100
    var contraste: Int    // 0-100
    var color: Int        // 0-100
    var horizonte: Int    // grados de inclinacion, 0 = derecho

    /// Nombre de lo que la IA tiene en el cuadro, para ponerlo en la caja.
    var etiqueta: String
    /// Sujeto y encuadre recomendado. nil si no vio nada claro.
    var guia: Guia?
}

/// Analiza la escena con Vision de Apple: luz, contraste, color, caras,
/// horizonte y que hay en el cuadro. Con eso califica y elige las camaras.
enum AestheticAnalyzer {

    static func analizar(_ imagen: UIImage) async -> Analisis? {
        let base = FilterEngine.normalizar(imagen)
        guard let cg = base.cgImage else { return nil }

        let medidas = metricas(base)

        return await withCheckedContinuation { (continuacion: CheckedContinuation<Analisis?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let manejador = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])

                let clasificar = VNClassifyImageRequest()
                let carasRequest = VNDetectFaceRectanglesRequest()
                let saliencia = VNGenerateAttentionBasedSaliencyImageRequest()
                let horizonteRequest = VNDetectHorizonRequest()

                do {
                    try manejador.perform([clasificar, carasRequest, saliencia, horizonteRequest])
                } catch {
                    continuacion.resume(returning: nil)
                    return
                }

                let etiquetas = (clasificar.results ?? [])
                    .filter { $0.confidence > 0.12 }
                    .prefix(3)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

                let caras = carasRequest.results ?? []
                let objetos = (saliencia.results?.first as? VNSaliencyImageObservation)?.salientObjects

                // Vision devuelve radianes; pasamos a grados.
                let inclinacion: Double? = (horizonteRequest.results?.first).map {
                    abs(Double($0.angle) * 180.0 / .pi)
                }

                let resultado = calificar(
                    luz: medidas.luz,
                    contraste: medidas.contraste,
                    color: medidas.color,
                    calidez: medidas.calidez,
                    caras: caras,
                    objetos: objetos ?? [],
                    etiquetas: Array(etiquetas),
                    horizonte: inclinacion
                )

                continuacion.resume(returning: resultado)
            }
        }
    }

    // MARK: - Puntaje

    private static func calificar(
        luz: Double,
        contraste: Double,
        color: Double,
        calidez: Double,
        caras: [VNFaceObservation],
        objetos: [VNRectangleObservation],
        etiquetas: [String],
        horizonte: Double?
    ) -> Analisis {

        var puntos = 0
        var consejos: [String] = []

        // 1. luz: no se juzga. Como en Framed, con poca o mucha luz siempre
        //    se puede sacar algo aesthetic; lo unico que cambia es la camara
        //    que conviene, no el puntaje. Por eso la luz solo se mide.
        puntos += 28

        // 2. contraste (20)
        if contraste >= 0.18 {
            puntos += 20
        } else if contraste >= 0.08 {
            puntos += 18
        } else {
            puntos += 16
        }

        // 3. color (20): una escena sin color tambien es aesthetic en B y N
        if color >= 0.22 {
            puntos += 20
        } else if color >= 0.10 {
            puntos += 19
        } else {
            puntos += 17
        }

        // 4. composicion (20) usando el objeto que mas llama la atencion
        if let principal = objetos.first {
            let centro = CGPoint(
                x: principal.boundingBox.midX,
                y: principal.boundingBox.midY
            )
            let tercios = [
                CGPoint(x: 1.0 / 3.0, y: 1.0 / 3.0),
                CGPoint(x: 2.0 / 3.0, y: 1.0 / 3.0),
                CGPoint(x: 1.0 / 3.0, y: 2.0 / 3.0),
                CGPoint(x: 2.0 / 3.0, y: 2.0 / 3.0)
            ]
            let distancia = tercios
                .map { hypot($0.x - centro.x, $0.y - centro.y) }
                .min() ?? 1

            if distancia <= 0.12 {
                puntos += 20
            } else if distancia <= 0.22 {
                puntos += 18
                consejos.append(String(localized: "Mueve el sujeto un poco para que caiga en un cruce de tercios."))
            } else {
                puntos += 16
                consejos.append(String(localized: "El sujeto esta centrado: recorrelo a un tercio del cuadro."))
            }
        } else {
            puntos += 17
        }

        // 5. personas (10)
        if (1...2).contains(caras.count) {
            puntos += 10
        } else if caras.isEmpty {
            puntos += 9
        } else {
            puntos += 8
            consejos.append(String(localized: "Hay varias caras: acerca o enfoca a una sola."))
        }

        // 6. horizonte torcido: resta poco, solo para avisar del nivel
        let inclinacion = horizonte ?? 0
        if inclinacion > 1.5 {
            puntos -= min(5, Int(inclinacion))
            consejos.append(String(
                format: String(localized: "El horizonte esta %.0f grados torcido: usa el nivel de la cuadricula."),
                inclinacion
            ))
        }

        // 7. consejos de luz: cortos y utiles.
        if luz > 0.78 {
            consejos.append(String(localized: "Hay mucha luz: baja un poco la exposicion para no quemar el cielo."))
        } else if luz < 0.20 {
            consejos.append(String(localized: "Hay poca luz: acerca o prende el flash calido."))
        }

        if consejos.isEmpty {
            consejos.append(String(localized: "Todo bien: dispara y elige el look que mas te guste."))
        }

        let puntaje = min(max(puntos, 0), 100)
        let carasCount = caras.count

        return Analisis(
            puntaje: puntaje,
            resumen: resumenPara(puntaje),
            consejos: Array(consejos.prefix(3)),
            etiquetas: etiquetas,
            caras: carasCount,
            sugerencias: sugerencias(
                etiquetas: etiquetas,
                caras: carasCount,
                luz: luz,
                contraste: contraste,
                color: color,
                calidez: calidez,
                horizonte: inclinacion
            ),
            luz: Int((luz * 100).rounded()),
            contraste: min(Int((contraste / 0.30 * 100).rounded()), 100),
            color: min(Int((color / 0.35 * 100).rounded()), 100),
            horizonte: Int(inclinacion.rounded()),
            etiqueta: etiquetas.first ?? String(localized: "el sujeto"),
            guia: componerGuia(caras: caras, objetos: objetos)
        )
    }

    // MARK: - Guia en vivo

    /// Seguimiento rapido mientras la guia esta abierta: solo busca caras y
    /// el objeto que mas llama la atencion. Sin clasificar ni medir luz, para
    /// que pueda repetirse cada segundo sin gastar bateria.
    static func seguir(_ imagen: UIImage) async -> Guia? {
        let base = reducir(FilterEngine.normalizar(imagen), maximo: 720)
        guard let cg = base.cgImage else { return nil }

        return await withCheckedContinuation { (continuacion: CheckedContinuation<Guia?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let manejador = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
                let carasRequest = VNDetectFaceRectanglesRequest()
                let saliencia = VNGenerateAttentionBasedSaliencyImageRequest()

                do {
                    try manejador.perform([carasRequest, saliencia])
                } catch {
                    continuacion.resume(returning: nil)
                    return
                }

                let objetos = (saliencia.results?.first as? VNSaliencyImageObservation)?.salientObjects

                continuacion.resume(returning: componerGuia(
                    caras: carasRequest.results ?? [],
                    objetos: objetos ?? []
                ))
            }
        }
    }

    /// Guia a partir de una caja ya seguida cuadro a cuadro. La usa el
    /// rastreador en vivo: la caja se recalcula en cada frame y la
    /// instruccion cambia al instante.
    static func guia(
        paraCaja caja: CGRect,
        esCara: Bool,
        destinoAnterior: CGPoint? = nil
    ) -> Guia? {
        guard caja.width > 0.004, caja.height > 0.004 else { return nil }
        return componerGuia(
            nucleo: recortar(caja),
            otros: [],
            esCara: esCara,
            destinoAnterior: destinoAnterior
        )
    }

    /// Elige al sujeto, calcula su caja y el cruce de tercios que le queda
    /// mejor, y arma la instruccion para mover el telefono. El cruce cambia
    /// segun donde este el sujeto y que mas haya en el cuadro.
    private static func componerGuia(
        caras: [VNFaceObservation],
        objetos: [VNRectangleObservation]
    ) -> Guia? {
        var nucleo: CGRect?
        var otros: [CGRect] = []

        if let primera = caras.first {
            var union = cajaArriba(primera.boundingBox)
            for cara in caras.dropFirst() {
                union = union.union(cajaArriba(cara.boundingBox))
            }
            nucleo = union
        } else if !objetos.isEmpty {
            var indice = 0
            for (i, objeto) in objetos.enumerated()
            where area(objeto.boundingBox) > area(objetos[indice].boundingBox) {
                indice = i
            }

            nucleo = cajaArriba(objetos[indice].boundingBox)
            otros = objetos.enumerated()
                .filter { $0.offset != indice }
                .map { cajaArriba($0.element.boundingBox) }
        }

        guard let base = nucleo else { return nil }

        return componerGuia(nucleo: base, otros: otros, esCara: !caras.isEmpty, destinoAnterior: nil)
    }

    private static func componerGuia(
        nucleo base: CGRect,
        otros: [CGRect],
        esCara: Bool,
        destinoAnterior: CGPoint? = nil
    ) -> Guia? {
        let centro = CGPoint(x: base.midX, y: base.midY)

        // Caja que se dibuja: en caras incluye cabeza y algo de cuerpo; en
        // objetos, un poco de aire alrededor.
        var ancho: CGFloat
        var alto: CGFloat

        if esCara {
            ancho = min(max(base.width * 2.05, 0.26), 0.80)
            alto = min(max(base.height * 2.45, 0.30), 0.86)
        } else {
            ancho = min(max(base.width * 1.28, 0.22), 0.76)
            alto = min(max(base.height * 1.28, 0.22), 0.76)
        }

        let dibujo = CGRect(
            x: centro.x - ancho / 2,
            y: esCara ? centro.y - alto * 0.36 : centro.y - alto / 2,
            width: ancho,
            height: alto
        )

        // Cruces de tercios. Los de abajo se usan menos: casi siempre el
        // sujeto queda mejor arriba.
        let cruces = [
            CGPoint(x: 1.0 / 3.0, y: 0.34),
            CGPoint(x: 2.0 / 3.0, y: 0.34),
            CGPoint(x: 1.0 / 3.0, y: 0.63),
            CGPoint(x: 2.0 / 3.0, y: 0.63)
        ]

        var destino = cruces[0]
        var mejor = Double.infinity

        for cruce in cruces {
            var puntos = hypot(cruce.x - centro.x, cruce.y - centro.y) * 1.5

            // Que el sujeto no se encime con otro objeto que llama la atencion.
            for otro in otros
            where abs(cruce.x - otro.midX) < 0.16 && abs(cruce.y - otro.midY) < 0.20 {
                puntos += 0.25
            }

            // En retratos los ojos van arriba.
            if esCara {
                puntos += abs(cruce.y - 0.34) * 0.9
            }

            // Quedarse del mismo lado del cuadro se siente mas natural.
            puntos += cruce.x > 0.5
                ? (0.5 - centro.x) * 0.24
                : (centro.x - 0.5) * 0.24

            // Mantener el mismo destino evita que el punto salte de lado.
            if let anterior = destinoAnterior {
                let salto = hypot(cruce.x - anterior.x, cruce.y - anterior.y)
                if salto < 0.05 {
                    puntos -= 0.18
                } else if salto > 0.1 {
                    puntos += salto * 0.9
                }
            }

            if puntos < mejor {
                mejor = puntos
                destino = cruce
            }
        }

        let dx = destino.x - centro.x
        let dy = destino.y - centro.y
        let cerca = abs(dx) < 0.06 && abs(dy) < 0.065

        var listo = cerca
        var partes: [String] = []

        if !cerca {
            if dx >= 0.045 {
                partes.append(String(localized: "a la izquierda"))
            } else if dx <= -0.045 {
                partes.append(String(localized: "a la derecha"))
            }

            if dy >= 0.05 {
                partes.append(String(localized: "arriba"))
            } else if dy <= -0.05 {
                partes.append(String(localized: "abajo"))
            }
        }

        var instruccion: String

        if listo {
            instruccion = String(localized: "Buen encuadre. Dispara.")
        } else {
            let direccion = partes.joined(separator: String(localized: " y "))
            instruccion = String(
                format: String(localized: "Apunta el iPhone %@"),
                direccion
            )
        }

        // La IA acerca sola: si el sujeto esta lejos, sube el zoom en vez de
        // pedirle al usuario que camine. Si esta muy grande, lo baja.
        var zoom: CGFloat?
        let altoCaja = dibujo.height

        if altoCaja < 0.30 {
            zoom = min(max(0.52 / max(altoCaja, 0.06), 1.2), 2.0)
        } else if altoCaja > 0.82 {
            zoom = max(0.66 / altoCaja, 0.6)
        }

        return Guia(
            sujeto: recortar(dibujo),
            destino: destino,
            listo: listo,
            instruccion: instruccion,
            zoom: zoom
        )
    }

    /// Pasa una caja de Vision (origen abajo a la izquierda) al origen
    /// de arriba a la izquierda que usa la pantalla.
    private static func cajaArriba(_ caja: CGRect) -> CGRect {
        CGRect(
            x: caja.minX,
            y: 1 - caja.maxY,
            width: caja.width,
            height: caja.height
        )
    }

    private static func area(_ caja: CGRect) -> CGFloat {
        caja.width * caja.height
    }

    /// Deja la caja dentro del cuadro.
    private static func recortar(_ caja: CGRect) -> CGRect {
        let ancho = min(caja.width, 0.98)
        let alto = min(caja.height, 0.98)

        return CGRect(
            x: min(max(caja.minX, 0.01), 0.99 - ancho),
            y: min(max(caja.minY, 0.01), 0.99 - alto),
            width: ancho,
            height: alto
        )
    }

    /// Version chiquita de la foto, para que el seguimiento sea rapido.
    private static func reducir(_ imagen: UIImage, maximo: CGFloat) -> UIImage {
        let mayor = max(imagen.size.width, imagen.size.height)
        guard mayor > maximo else { return imagen }

        let escala = maximo / mayor
        let tamano = CGSize(
            width: imagen.size.width * escala,
            height: imagen.size.height * escala
        )

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = true

        return UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }
    }

    private static func resumenPara(_ puntaje: Int) -> String {
        switch puntaje {
        case 88...100: return String(localized: "Muy aesthetic. Dispara ya.")
        case 78..<88: return String(localized: "Buen cuadro. Elige una de estas camaras.")
        default: return String(localized: "Listo para disparar. Cualquiera de estas le queda.")
        }
    }

    /// Hasta tres camaras que le quedan a lo que se ve en el cuadro,
    /// en orden de que tan bien pegan.
    private static func sugerencias(
        etiquetas: [String],
        caras: Int,
        luz: Double,
        contraste: Double,
        color: Double,
        calidez: Double,
        horizonte: Double
    ) -> [FilterPreset] {
        let texto = etiquetas.joined(separator: " ")

        func contiene(_ palabras: [String]) -> Bool {
            palabras.contains { texto.contains($0) }
        }

        var lista: [FilterPreset] = []

        func agregar(_ preset: FilterPreset) {
            if !lista.contains(preset) {
                lista.append(preset)
            }
        }

        // de noche manda el look frio o el negro
        if luz < 0.25 {
            agregar(.tealNight)
            agregar(.y2kDigi)
            agregar(.noir)
        }

        // con mucho sol, peliculas que aguantan sin quemarse
        if luz > 0.72 {
            agregar(.ektar100)
            agregar(.velvia)
            agregar(.provia)
        }

        // escena calida: refuerza con rollo tibio. Fria: contrasta con frio.
        if calidez > 0.05 {
            agregar(.kodakGold)
            agregar(.portra)
            agregar(.goldenHour)
        } else if calidez < -0.05 {
            agregar(.cinestill)
            agregar(.tealNight)
            agregar(.provia)
        }

        // mucho contraste: peliculas suaves. Plano: sube el contraste.
        if contraste > 0.26 {
            agregar(.portra)
            agregar(.fujiPro400)
            agregar(.polaroid600)
        } else if contraste < 0.09 {
            agregar(.kodachrome)
            agregar(.ektar100)
            agregar(.bleachBypass)
        }

        // hay gente: pelicula de retrato
        if caras > 0 || contiene(["person", "portrait", "selfie", "face", "people"]) {
            agregar(.portra)
            agregar(.kodakGold)
            agregar(.warmFlash)
            agregar(.polaroidGo)
        }

        if contiene(["food", "meal", "drink", "coffee", "dessert", "fruit"]) {
            agregar(.warmFlash)
            agregar(.kodachrome)
            agregar(.instaxMini)
        }

        // cielo, playa, atardecer: saturar un poco con diapositiva
        if contiene(["sky", "cloud", "beach", "sunset", "sunrise", "sea", "ocean"]) {
            agregar(.velvia)
            agregar(.ektar100)
            agregar(.goldenHour)
        }

        if contiene(["plant", "flower", "tree", "forest", "nature", "garden", "leaf"]) {
            agregar(.provia)
            agregar(.velvia)
            agregar(.fujiPro400)
        }

        if contiene(["building", "architecture", "city", "street", "skyscraper", "bridge"]) {
            agregar(.ektachrome)
            agregar(.bleachBypass)
            agregar(.contaxT2)
        }

        if contiene(["car", "vehicle", "motorcycle", "bicycle", "traffic"]) {
            agregar(.chatarraCCD)
            agregar(.vhs)
            agregar(.disposable)
        }

        if contiene(["night", "dark", "neon", "concert", "light", "party"]) {
            agregar(.vhs)
            agregar(.y2kDigi)
            agregar(.vaporwave)
        }

        // sin color en la escena: mejor blanco y negro
        if color < 0.10 {
            agregar(.triX)
            agregar(.noir)
        }

        // horizonte torcido: un look duro disimula menos, mejor clasico
        if horizonte > 4 {
            agregar(.kodakGold)
        }

        agregar(.dazzClassic)
        agregar(.kodakGold)
        agregar(.polaroid600)

        // Que no salgan tres de la misma familia: una compacta, una reflex o
        // una instantanea. Asi la eleccion se siente variada y no repetida.
        var elegidas: [FilterPreset] = []
        var familias: Set<String> = []

        for preset in lista where !elegidas.contains(preset) {
            let familia = String(describing: preset.familia)
            if !familias.contains(familia) {
                elegidas.append(preset)
                familias.insert(familia)
            }
            if elegidas.count == 3 { break }
        }

        if elegidas.count < 3 {
            for preset in lista where !elegidas.contains(preset) {
                elegidas.append(preset)
                if elegidas.count == 3 { break }
            }
        }

        return Array(elegidas.prefix(3))
    }

    // MARK: - Medidas de la imagen

    /// Reduce la foto a 32x32 y mide luz, contraste, color y calidez.
    /// Rapido y suficiente.
    private static func metricas(
        _ imagen: UIImage
    ) -> (luz: Double, contraste: Double, color: Double, calidez: Double) {
        let lado = 32
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: lado, height: lado),
            format: formato
        )
        let chica = renderer.image { _ in
            imagen.draw(in: CGRect(x: 0, y: 0, width: lado, height: lado))
        }
        guard let cg = chica.cgImage else { return (0.5, 0.1, 0.2, 0) }

        let bytes = lado * lado * 4
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes)
        defer { buffer.deallocate() }

        guard let contexto = CGContext(
            data: buffer,
            width: lado,
            height: lado,
            bitsPerComponent: 8,
            bytesPerRow: lado * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (0.5, 0.1, 0.2, 0)
        }

        contexto.draw(cg, in: CGRect(x: 0, y: 0, width: lado, height: lado))

        var suma = 0.0
        var sumaCuadrados = 0.0
        var sumaColor = 0.0
        var sumaCalidez = 0.0
        let total = Double(lado * lado)

        for i in stride(from: 0, to: bytes, by: 4) {
            let r = Double(buffer[i]) / 255.0
            let g = Double(buffer[i + 1]) / 255.0
            let b = Double(buffer[i + 2]) / 255.0

            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            suma += luma
            sumaCuadrados += luma * luma

            let maximo = max(r, max(g, b))
            let minimo = min(r, min(g, b))
            sumaColor += (maximo - minimo)
            sumaCalidez += (r - b)
        }

        let media = suma / total
        let varianza = max(sumaCuadrados / total - media * media, 0)

        return (
            media,
            varianza.squareRoot(),
            sumaColor / total,
            sumaCalidez / total
        )
    }
}
