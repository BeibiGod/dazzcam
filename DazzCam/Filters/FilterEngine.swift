import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Parametros de un look. Todo se aplica en el mismo orden para todas las camaras.
struct AjusteFoto {
    var temperatura: CGFloat = 6500      // hacia donde se mueve el balance
    var tinte: CGFloat = 0               // verde - / magenta +
    var saturacion: CGFloat = 1
    var contraste: CGFloat = 1
    var brillo: CGFloat = 0
    var desvanecido: CGFloat = 0         // sube los negros (look viejo)
    var vineta: CGFloat = 0              // 0 = nada, 1 = esquinas negras
    var grano: CGFloat = 0               // 0 = nada, 0.2 = pelicula sucia
    var blancoYNegro: Bool = false
    var movimiento: CGFloat = 0          // cuadros dobles tipo VHS
}

/// Aplica los looks de pelicula a fotos y a video.
enum FilterEngine {

    private static let contexto = CIContext()

    // MARK: - API

    static func aplicar(_ preset: FilterPreset, a imagen: UIImage) -> UIImage {
        guard preset != .original else { return imagen }

        let base = normalizar(imagen)
        guard let entrada = CIImage(image: base) else { return imagen }
        guard let salida = cadena(preset, entrada: entrada) else { return imagen }

        guard let cg = contexto.createCGImage(salida, from: entrada.extent) else {
            return imagen
        }
        return UIImage(cgImage: cg, scale: base.scale, orientation: .up)
    }

    static func cadena(_ preset: FilterPreset, entrada: CIImage) -> CIImage? {
        guard preset != .original else { return entrada }
        return aplicar(ajuste(preset), a: entrada)
    }

    // MARK: - Tabla de looks

    static func ajuste(_ preset: FilterPreset) -> AjusteFoto {
        var a = AjusteFoto()

        switch preset {
        case .original:
            break

        case .portra:
            a.temperatura = 7100
            a.saturacion = 1.02
            a.contraste = 0.97
            a.desvanecido = 0.02
            a.grano = 0.06
            a.vineta = 0.3

        case .superia:
            a.temperatura = 6600
            a.saturacion = 1.16
            a.contraste = 1.08
            a.grano = 0.09
            a.vineta = 0.35

        case .kodachrome:
            a.temperatura = 7400
            a.saturacion = 1.25
            a.contraste = 1.12
            a.grano = 0.05
            a.vineta = 0.25

        case .instColor:
            a.temperatura = 8000
            a.saturacion = 1.15
            a.contraste = 0.95
            a.desvanecido = 0.03
            a.vineta = 0.3

        case .dazzClassic:
            a.temperatura = 7000
            a.saturacion = 1.05
            a.contraste = 1.05
            a.grano = 0.07
            a.vineta = 0.35

        case .cinestill:
            a.temperatura = 5400
            a.tinte = -8
            a.saturacion = 1.1
            a.contraste = 1.05
            a.desvanecido = 0.03
            a.grano = 0.1
            a.vineta = 0.3

        case .hp5:
            a.blancoYNegro = true
            a.contraste = 1.2
            a.grano = 0.14
            a.vineta = 0.4

        case .polaroid:
            a.temperatura = 7800
            a.saturacion = 0.85
            a.contraste = 0.9
            a.desvanecido = 0.06
            a.vineta = 0.5
            a.grano = 0.05

        case .lomo:
            a.saturacion = 1.35
            a.contraste = 1.2
            a.vineta = 0.85
            a.grano = 0.1

        case .crossProcess:
            a.temperatura = 6000
            a.tinte = 15
            a.saturacion = 1.3
            a.contraste = 1.25
            a.desvanecido = 0.05

        case .bleachBypass:
            a.saturacion = 0.45
            a.contraste = 1.35
            a.grano = 0.08

        case .faded90s:
            a.temperatura = 7200
            a.saturacion = 0.75
            a.contraste = 0.85
            a.desvanecido = 0.1
            a.grano = 0.08

        case .copper:
            a.temperatura = 8500
            a.tinte = 8
            a.saturacion = 1.2
            a.contraste = 1.12
            a.grano = 0.07

        case .vhs:
            a.temperatura = 6800
            a.tinte = -10
            a.saturacion = 0.9
            a.contraste = 0.9
            a.desvanecido = 0.08
            a.grano = 0.15
            a.movimiento = 1.0

        case .d3d:
            a.temperatura = 6200
            a.saturacion = 1.2
            a.contraste = 1.15
            a.vineta = 0.5
            a.grano = 0.12

        case .tealNight:
            a.temperatura = 5200
            a.tinte = -12
            a.saturacion = 1.1
            a.contraste = 1.1
            a.vineta = 0.45
            a.grano = 0.1

        case .warmFlash:
            a.temperatura = 8200
            a.saturacion = 1.1
            a.contraste = 1.05
            a.desvanecido = 0.02
            a.vineta = 0.3

        case .noir:
            a.blancoYNegro = true
            a.contraste = 1.45
            a.vineta = 0.8
            a.grano = 0.1

        case .vaporwave:
            a.temperatura = 6000
            a.tinte = 25
            a.saturacion = 1.4
            a.contraste = 1.05
            a.desvanecido = 0.04
            a.vineta = 0.3
        }

        return a
    }

    // MARK: - Cadena generica

    private static func aplicar(_ a: AjusteFoto, a imagen: CIImage) -> CIImage? {
        var actual = imagen

        // 1. balance de blancos
        if a.temperatura != 6500 || a.tinte != 0 {
            let f = CIFilter.temperatureAndTint()
            f.inputImage = actual
            f.neutral = CIVector(x: 6500, y: 0)
            f.targetNeutral = CIVector(x: a.temperatura, y: a.tinte)
            if let salida = f.outputImage { actual = salida }
        }

        // 2. color
        if a.saturacion != 1 || a.contraste != 1 || a.brillo != 0 {
            let f = CIFilter.colorControls()
            f.inputImage = actual
            f.saturation = Float(a.saturacion)
            f.contrast = Float(a.contraste)
            f.brightness = Float(a.brillo)
            if let salida = f.outputImage { actual = salida }
        }

        // 3. blanco y negro
        if a.blancoYNegro {
            let f = CIFilter.photoEffectMono()
            f.inputImage = actual
            if let salida = f.outputImage { actual = salida }
        }

        // 4. negros levantados
        if a.desvanecido > 0 {
            let f = CIFilter.colorMatrix()
            f.inputImage = actual
            f.biasVector = CIVector(x: a.desvanecido, y: a.desvanecido, z: a.desvanecido, w: 0)
            if let salida = f.outputImage { actual = salida }
        }

        // 5. vineta
        if a.vineta > 0 {
            let f = CIFilter.vignette()
            f.inputImage = actual
            f.intensity = Float(a.vineta * 1.6)
            f.radius = Float(2.4 - (a.vineta * 0.6))
            if let salida = f.outputImage { actual = salida }
        }

        // 6. grano
        if a.grano > 0, let conGrano = grano(actual, cantidad: a.grano) {
            actual = conGrano
        }

        return actual
    }

    // MARK: - Grano

    private static let ruidoBase: CIImage? = {
        let f = CIFilter.randomGenerator()
        return f.outputImage
    }()

    private static func grano(_ imagen: CIImage, cantidad: CGFloat) -> CIImage? {
        guard let ruido = ruidoBase?.cropped(to: imagen.extent) else { return nil }

        let gris = CIFilter.colorMatrix()
        gris.inputImage = ruido
        gris.rVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        gris.gVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        gris.bVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        gris.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        guard let grisSalida = gris.outputImage else { return nil }

        let transparencia = CIFilter.colorMatrix()
        transparencia.inputImage = grisSalida
        transparencia.aVector = CIVector(x: 0, y: 0, z: 0, w: cantidad)
        guard let capa = transparencia.outputImage else { return nil }

        let mezcla = CIFilter.softLightBlendMode()
        mezcla.inputImage = capa
        mezcla.backgroundImage = imagen
        return mezcla.outputImage
    }

    // MARK: - Utilidades

    /// Redibuja la imagen derecha para evitar fotos torcidas tras filtrar.
    static func normalizar(_ imagen: UIImage) -> UIImage {
        guard imagen.imageOrientation != .up else { return imagen }

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = imagen.scale
        formato.opaque = true
        let renderer = UIGraphicsImageRenderer(size: imagen.size, format: formato)

        return renderer.image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: imagen.size))
        }
    }
}
