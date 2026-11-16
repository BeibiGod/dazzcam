import CoreGraphics
import UIKit
import Vision

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
            horizonte: Int(inclinacion.rounded())
        )
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
