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
}

/// Analiza la escena actual con Vision de Apple: brillo, contraste, color,
/// composicion, caras y que hay en el cuadro. No es magia: son mediciones
/// reales convertidas en un puntaje y en consejos concretos.
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

                do {
                    try manejador.perform([clasificar, carasRequest, saliencia])
                } catch {
                    continuacion.resume(returning: nil)
                    return
                }

                let etiquetas = (clasificar.results ?? [])
                    .filter { $0.confidence > 0.12 }
                    .prefix(3)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

                let caras = carasRequest.results ?? []
                let objetos = (saliencia.results?.first as? VNSaliencyImageObservation)?.salientObjects ?? []

                let resultado = calificar(
                    luz: medidas.luz,
                    contraste: medidas.contraste,
                    color: medidas.color,
                    caras: caras,
                    objetos: objetos,
                    etiquetas: Array(etiquetas)
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
        caras: [VNFaceObservation],
        objetos: [VNRectangleObservation],
        etiquetas: [String]
    ) -> Analisis {

        var puntos = 0
        var consejos: [String] = []

        // 1. luz (30)
        switch luz {
        case 0.45...0.72:
            puntos += 30
        case 0.32..<0.45:
            puntos += 20
            consejos.append("Esta algo oscura: gira hacia una ventana o enciende una luz.")
        case 0.72...0.86:
            puntos += 18
            consejos.append("Hay zonas muy claras: toca la parte brillante para bajar la exposicion.")
        case ..<0.32:
            puntos += 8
            consejos.append("Muy oscura: sin luz no hay detalle, busca otra zona.")
        default:
            puntos += 6
            consejos.append("Esta quemada: busca una sombra o baja la exposicion tocando lo claro.")
        }

        // 2. contraste (20)
        if contraste >= 0.18 {
            puntos += 20
        } else if contraste >= 0.10 {
            puntos += 12
            consejos.append("Le falta contraste: mete algo oscuro y algo claro en el mismo cuadro.")
        } else {
            puntos += 5
            consejos.append("Se ve plana y gris. Busca una sombra o un color fuerte cerca.")
        }

        // 3. color (20)
        if color >= 0.22 {
            puntos += 20
        } else if color >= 0.12 {
            puntos += 12
        } else {
            puntos += 6
            consejos.append("Colores apagados: acerca algo con color fuerte al cuadro.")
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
                puntos += 13
                consejos.append("Mueve el sujeto un poco para que caiga en un cruce de tercios.")
            } else {
                puntos += 7
                consejos.append("El sujeto esta centrado: recorrelo a un tercio del cuadro.")
            }
        } else {
            puntos += 9
            consejos.append("No encontre un sujeto claro: llena el cuadro con algo.")
        }

        // 5. personas (10)
        if (1...2).contains(caras.count) {
            puntos += 10
        } else if caras.isEmpty {
            puntos += 6
        } else {
            puntos += 4
            consejos.append("Hay varias caras: acerca o enfoca a una sola.")
        }

        // si todo esta bien, al menos un consejo util
        if consejos.isEmpty {
            consejos.append("Se ve bien. Dispara ahora, la luz es la correcta.")
        }

        let puntaje = min(max(puntos, 0), 100)

        return Analisis(
            puntaje: puntaje,
            resumen: resumenPara(puntaje),
            consejos: Array(consejos.prefix(3)),
            etiquetas: etiquetas,
            caras: caras.count,
            sugerencias: sugerencias(etiquetas: etiquetas, caras: caras.count, luz: luz)
        )
    }

    private static func resumenPara(_ puntaje: Int) -> String {
        switch puntaje {
        case 85...100: return "Muy aesthetic. Dispara ya."
        case 70..<85: return "Va bien, solo un ajuste y queda."
        case 50..<70: return "Se puede arreglar moviendote un poco."
        default: return "Mejor cambia de lugar antes de disparar."
        }
    }

    /// Hasta tres camaras que le quedan a lo que se ve en el cuadro,
    /// en orden de que tan bien pegan.
    private static func sugerencias(etiquetas: [String], caras: Int, luz: Double) -> [FilterPreset] {
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

        if luz < 0.25 {
            agregar(.tealNight)
            agregar(.noir)
            agregar(.d3d)
        }

        if caras > 0 || contiene(["person", "portrait", "selfie", "face", "people"]) {
            agregar(.portra)
            agregar(.kodakGold)
            agregar(.warmFlash)
        }

        if contiene(["food", "meal", "drink", "coffee", "dessert", "fruit"]) {
            agregar(.warmFlash)
            agregar(.kodachrome)
            agregar(.instaxMini)
        }

        if contiene(["sky", "cloud", "beach", "sunset", "sunrise", "sea", "ocean"]) {
            agregar(.kodakGold)
            agregar(.ektar100)
            agregar(.superia)
        }

        if contiene(["plant", "flower", "tree", "forest", "nature", "garden", "leaf"]) {
            agregar(.fujiPro400)
            agregar(.agfaVista)
            agregar(.superia)
        }

        if contiene(["building", "architecture", "city", "street", "skyscraper", "bridge"]) {
            agregar(.ektar100)
            agregar(.bleachBypass)
            agregar(.d3d)
        }

        if contiene(["car", "vehicle", "motorcycle", "bicycle", "traffic"]) {
            agregar(.chatarraCCD)
            agregar(.vhs)
            agregar(.copper)
        }

        if contiene(["night", "dark", "neon", "concert", "light"]) {
            agregar(.vhs)
            agregar(.tealNight)
            agregar(.vaporwave)
        }

        agregar(.dazzClassic)
        agregar(.kodakGold)
        agregar(.polaroid600)

        return Array(lista.prefix(3))
    }

    // MARK: - Medidas de la imagen

    /// Reduce la foto a 32x32 y mide luz, contraste y color. Rapido y suficiente.
    private static func metricas(_ imagen: UIImage) -> (luz: Double, contraste: Double, color: Double) {
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
        guard let cg = chica.cgImage else { return (0.5, 0.1, 0.2) }

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
            return (0.5, 0.1, 0.2)
        }

        contexto.draw(cg, in: CGRect(x: 0, y: 0, width: lado, height: lado))

        var suma = 0.0
        var sumaCuadrados = 0.0
        var sumaColor = 0.0
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
        }

        let media = suma / total
        let varianza = max(sumaCuadrados / total - media * media, 0)

        return (media, varianza.squareRoot(), sumaColor / total)
    }
}
