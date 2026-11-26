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
    var rayones: CGFloat = 0             // rayones finos de pelicula vieja
    var fuga: CGFloat = 0                // luz que se cuela por el borde
    var blancoYNegro: Bool = false
    /// Vision nocturna: 0 = normal, 1 = verde de videocamara con intensificador.
    var vision: CGFloat = 0
    /// Resplandor alrededor de las luces fuertes, como en un intensificador.
    var halacion: CGFloat = 0
    /// Separacion de color en los bordes: lo que hace una optica vieja o una
    /// cinta de video mal alineada.
    var aberracion: CGFloat = 0
    /// Suavidad de la optica: 0 = nitida, 1 = blanda como una videocamara.
    var suavidad: CGFloat = 0
    /// Curva de tono: 5 puntos para x = 0, 0.25, 0.5, 0.75 y 1.
    var curva: [CGFloat]? = nil
    /// Flash directo: ilumina el centro y deja caer las orillas.
    var flash: CGFloat = 0
    /// Nitidez extra para las camaras que se ven limpias.
    var nitidez: CGFloat = 0
}

/// Lo que el usuario puede mover con los dedos. nil = lo que trae la camara.
struct ControlesLook: Equatable, Codable {
    var intensidad: CGFloat = 1
    var rayones: CGFloat? = nil
    var fuga: CGFloat? = nil
    var grano: CGFloat? = nil
    var estiloFecha: EstiloFecha = .dazz

    // Ajustes finos del editor. nil = como viene de fabrica. Son opcionales
    // para que los ajustes guardados de antes se sigan leyendo.
    var exposicion: CGFloat? = nil
    var contraste: CGFloat? = nil
    var saturacion: CGFloat? = nil
    var temperatura: CGFloat? = nil

    // Efectos de pelicula estilo Framed. nil = apagado.
    var glow: CGFloat? = nil       // halo brillante (bloom)
    var fringe: CGFloat? = nil     // aberracion cromatica
    var vignette: CGFloat? = nil   // oscurecer esquinas
    var motion: CGFloat? = nil     // desenfoque de movimiento
    var halation: CGFloat? = nil   // halo calido de luz en los bordes brillantes
    var dust: CGFloat? = nil       // motas de polvo/pelicula

    // Ajustes finos extra (CoreImage). nil = como viene.
    var highlights: CGFloat? = nil // luces
    var shadows: CGFloat? = nil    // sombras
    var vibrance: CGFloat? = nil   // vibrancia
    var tinte: CGFloat? = nil      // tinte (magenta/verde)
    var sharpen: CGFloat? = nil    // nitidez

    /// true si el usuario no ha tocado nada.
    var automatico: Bool {
        abs(intensidad - 1) < 0.001 && rayones == nil && fuga == nil
            && grano == nil && estiloFecha == .dazz
            && exposicion == nil && contraste == nil
            && saturacion == nil && temperatura == nil
            && glow == nil && fringe == nil && vignette == nil && motion == nil
            && halation == nil && dust == nil
            && highlights == nil && shadows == nil && vibrance == nil
            && tinte == nil && sharpen == nil
    }
}

/// Generador chiquito y repetible. La misma semilla da el mismo patron, asi
/// cada foto o video tiene sus propios rayones y su propia fuga, pero al mover
/// la intensidad no se mueven de lugar.
private struct Azar {
    private var estado: UInt64

    init(_ semilla: UInt64) {
        estado = semilla &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func siguiente() -> UInt64 {
        estado = estado &+ 0x9E37_79B9_7F4A_7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func valor(_ rango: ClosedRange<CGFloat>) -> CGFloat {
        let unidad = CGFloat(siguiente() % 10_000) / 10_000
        return rango.lowerBound + (rango.upperBound - rango.lowerBound) * unidad
    }

    mutating func entero(_ limite: Int) -> Int {
        guard limite > 0 else { return 0 }
        return Int(siguiente() % UInt64(limite))
    }
}

/// Aplica los looks de pelicula a fotos y a video.
enum FilterEngine {

    private static let contexto = CIContext()

    // MARK: - API

    static func aplicar(
        _ preset: FilterPreset,
        a imagen: UIImage,
        controles: ControlesLook = ControlesLook(),
        semilla: UInt64 = 0,
        momento: UInt64 = 0,
        conTextura: Bool = true
    ) -> UIImage {
        guard preset != .original else { return imagen }

        let base = normalizar(imagen)
        guard let entrada = CIImage(image: base) else { return imagen }
        guard let salida = cadena(
            preset,
            entrada: entrada,
            controles: controles,
            semilla: semilla,
            momento: momento,
            conTextura: conTextura
        ) else { return imagen }

        guard let cg = contexto.createCGImage(salida, from: salida.extent) else {
            return imagen
        }
        return UIImage(cgImage: cg, scale: base.scale, orientation: .up)
    }

    /// `momento` es el numero de cuadro. En foto vale 0 y el patron queda
    /// quieto; en video cambia cuadro a cuadro para que los rayones se muevan
    /// como en un negativo de verdad.
    ///
    /// `conTextura` se apaga cuando la fecha se quema antes del dano de
    /// pelicula: asi el grano, los rayones y la fuga tambien pasan por encima
    /// de la fecha y no queda pegada como calcomania.
    static func cadena(
        _ preset: FilterPreset,
        entrada: CIImage,
        controles: ControlesLook = ControlesLook(),
        semilla: UInt64 = 0,
        momento: UInt64 = 0,
        conTextura: Bool = true
    ) -> CIImage? {
        guard preset != .original else { return entrada }

        let (a, fuerza) = ajusteEfectivo(preset, controles: controles)

        guard let mirado = aplicarLook(a, a: entrada) else { return nil }

        let base: CIImage

        if fuerza < 0.999,
           let mezcla = mezclar(
               mirado,
               con: entrada,
               cantidad: fuerza
           ) {
            base = mezcla
        } else {
            base = mirado
        }

        guard conTextura else { return efectosFilmicos(ajustesFinos(base, controles: controles), controles: controles) }

        return aplicarTextura(
            a,
            a: efectosFilmicos(ajustesFinos(base, controles: controles), controles: controles),
            semilla: semilla,
            momento: momento
        )
    }

    /// Solo el dano de pelicula (grano, rayones y fuga). Se usa para ponerlo
    /// encima de la fecha ya quemada, sin volver a aplicar el color.
    static func textura(
        _ preset: FilterPreset,
        a imagen: CIImage,
        controles: ControlesLook = ControlesLook(),
        semilla: UInt64 = 0,
        momento: UInt64 = 0
    ) -> CIImage? {
        guard preset != .original else { return imagen }

        let (a, _) = ajusteEfectivo(preset, controles: controles)
        return aplicarTextura(a, a: imagen, semilla: semilla, momento: momento)
    }

    static func textura(
        _ preset: FilterPreset,
        a imagen: UIImage,
        controles: ControlesLook = ControlesLook(),
        semilla: UInt64 = 0,
        momento: UInt64 = 0
    ) -> UIImage {
        guard preset != .original else { return imagen }

        let base = normalizar(imagen)
        guard let entrada = CIImage(image: base),
              let salida = textura(
                  preset,
                  a: entrada,
                  controles: controles,
                  semilla: semilla,
                  momento: momento
              ),
              let cg = contexto.createCGImage(salida, from: salida.extent)
        else { return imagen }

        return UIImage(cgImage: cg, scale: base.scale, orientation: .up)
    }

    /// Ajustes finos del editor: exposicion, contraste, saturacion y
    /// temperatura. Van despues del look y antes del dano de pelicula, para
    /// que el grano y los rayones caigan encima del color ya corregido.
    private static func ajustesFinos(
        _ imagen: CIImage,
        controles: ControlesLook
    ) -> CIImage {
        var salida = imagen

        if let exposicion = controles.exposicion, abs(exposicion) > 0.001,
           let filtro = CIFilter(name: "CIExposureAdjust") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(exposicion * 1.2, forKey: kCIInputEVKey)
            if let resultado = filtro.outputImage {
                salida = resultado
            }
        }

        let contraste = controles.contraste ?? 0
        let saturacion = controles.saturacion ?? 0

        if abs(contraste) > 0.001 || abs(saturacion) > 0.001,
           let filtro = CIFilter(name: "CIColorControls") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(1 + contraste * 0.5, forKey: kCIInputContrastKey)
            filtro.setValue(max(0, 1 + saturacion), forKey: kCIInputSaturationKey)
            if let resultado = filtro.outputImage {
                salida = resultado
            }
        }

        if let temperatura = controles.temperatura, abs(temperatura) > 0.001,
           let filtro = CIFilter(name: "CITemperatureAndTint") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filtro.setValue(
                CIVector(x: 6500 + temperatura * 2500, y: controles.tinte == nil ? 0 : (controles.tinte ?? 0) * 100),
                forKey: "inputTargetNeutral"
            )
            if let resultado = filtro.outputImage {
                salida = resultado
            }
        } else if let tinte = controles.tinte, abs(tinte) > 0.001,
                  let filtro = CIFilter(name: "CITemperatureAndTint") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filtro.setValue(CIVector(x: 6500, y: tinte * 100), forKey: "inputTargetNeutral")
            if let resultado = filtro.outputImage {
                salida = resultado
            }
        }

        // LUCES + SOMBRAS.
        if (controles.highlights != nil || controles.shadows != nil),
           let filtro = CIFilter(name: "CIHighlightShadowAdjust") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            // highlights: 1 = intacto, baja para recuperar; shadows: sube para aclarar.
            let luces = controles.highlights ?? 1
            let sombras = controles.shadows ?? 0
            filtro.setValue(max(0, min(1, luces)), forKey: "inputHighlightAmount")
            filtro.setValue(max(-1, min(1, sombras)), forKey: "inputShadowAmount")
            if let resultado = filtro.outputImage {
                salida = resultado
            }
        }

        // VIBRANCE.
        if let vibrance = controles.vibrance, abs(vibrance) > 0.001,
           let filtro = CIFilter(name: "CIVibrance") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(vibrance, forKey: kCIInputAmountKey)
            if let resultado = filtro.outputImage {
                salida = resultado
            }
        }

        // SHARPEN.
        if let sharpen = controles.sharpen, sharpen > 0.001,
           let filtro = CIFilter(name: "CISharpenLuminance") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(sharpen, forKey: kCIInputSharpnessKey)
            if let resultado = filtro.outputImage {
                salida = resultado
            }
        }

        return salida
    }

    /// Efectos de pelicula: glow, fringe, vignette, motion. Van despues de
    /// los ajustes finos y antes del dano (grano/rayones/fuga).
    private static func efectosFilmicos(
        _ imagen: CIImage,
        controles: ControlesLook
    ) -> CIImage {
        var salida = imagen
        let extento = salida.extent

        // GLOW: halo brillante (bloom).
        if let glow = controles.glow, glow > 0.001,
           let filtro = CIFilter(name: "CIBloom") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(glow, forKey: kCIInputIntensityKey)
            filtro.setValue(max(extento.width, extento.height) * 0.02, forKey: kCIInputRadiusKey)
            if let r = filtro.outputImage { salida = r.cropped(to: extento) }
        }

        // FRINGE: aberracion cromatica, separa rojo y azul en los bordes.
        if let fringe = controles.fringe, fringe > 0.001 {
            salida = aberracionCromatica(salida, cantidad: fringe)
        }

        // VIGNETTE: oscurece las esquinas.
        if let vignette = controles.vignette, vignette > 0.001,
           let filtro = CIFilter(name: "CIVignette") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(vignette, forKey: kCIInputIntensityKey)
            filtro.setValue(max(extento.width, extento.height) * 0.5, forKey: kCIInputRadiusKey)
            if let r = filtro.outputImage { salida = r.cropped(to: extento) }
        }

        // MOTION: desenfoque de movimiento horizontal.
        if let motion = controles.motion, motion > 0.001,
           let filtro = CIFilter(name: "CIMotionBlur") {
            filtro.setValue(salida, forKey: kCIInputImageKey)
            filtro.setValue(motion * max(extento.width, extento.height) * 0.01, forKey: kCIInputRadiusKey)
            filtro.setValue(0, forKey: kCIInputAngleKey)
            if let r = filtro.outputImage { salida = r.cropped(to: extento) }
        }

        // HALATION: halo calido alrededor de lo que revienta de luz.
        if let halation = controles.halation, halation > 0.001,
           let bloom = CIFilter(name: "CIBloom") {
            bloom.setValue(salida, forKey: kCIInputImageKey)
            bloom.setValue(halation * 1.2, forKey: kCIInputIntensityKey)
            bloom.setValue(max(extento.width, extento.height) * 0.02, forKey: kCIInputRadiusKey)
            var r = bloom.outputImage ?? salida

            if let calor = CIFilter(name: "CIColorMatrix") {
                calor.setValue(r, forKey: kCIInputImageKey)
                calor.setValue(
                    CIVector(x: halation * 0.18, y: halation * 0.03, z: halation * 0.01, w: 0),
                    forKey: "inputBiasVector"
                )
                r = calor.outputImage ?? r
            }

            salida = r.cropped(to: extento)
        }

        // DUST: motas de polvo dispersas.
        if let dust = controles.dust, dust > 0.001 {
            salida = motas(salida, cantidad: dust)
        }

        return salida
    }

    /// Motas de polvo: puntos blancos dispersos, azar por coordenada.
    private static func motas(_ imagen: CIImage, cantidad: CGFloat) -> CIImage {
        let fuente = """
        kernel vec4 dust(sampler image, float amount) {
            vec4 c = sample(image, destCoord());
            vec2 p = floor(destCoord());
            float h = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
            if (h > 1.0 - amount * 0.02) { return vec4(1.0, 1.0, 1.0, c.a); }
            return c;
        }
        """

        guard let nucleo = CIColorKernel(source: fuente) else { return imagen }
        return nucleo.apply(
            extent: imagen.extent,
            roiCallback: { _, rect in rect },
            arguments: [imagen, cantidad]
        )?.cropped(to: imagen.extent) ?? imagen
    }

    /// Aberracion cromatica: rojo se corre a un lado, azul al otro.
    private static func aberracionCromatica(_ imagen: CIImage, cantidad: CGFloat) -> CIImage {
        let fuente = """
        kernel vec4 fringe(sampler image, float amount) {
            vec2 dc = destCoord();
            float shift = amount * samplerSize(image).x * 0.006;
            float r = sample(image, dc + vec2(shift, 0.0)).r;
            float g = sample(image, dc).g;
            float b = sample(image, dc - vec2(shift, 0.0)).b;
            float a = sample(image, dc).a;
            return vec4(r, g, b, a);
        }
        """

        guard let nucleo = CIColorKernel(source: fuente) else { return imagen }
        return nucleo.apply(
            extent: imagen.extent,
            roiCallback: { _, rect in rect.insetBy(dx: -10, dy: 0) },
            arguments: [imagen, cantidad]
        )?.cropped(to: imagen.extent) ?? imagen
    }

    /// Resuelve lo que trae la camara y lo que el usuario movio a mano.
    private static func ajusteEfectivo(
        _ preset: FilterPreset,
        controles: ControlesLook
    ) -> (AjusteFoto, CGFloat) {
        // La intensidad no va en linea recta: abajo se siente de verdad
        // suave y arriba se queda un poquito antes del tope. Asi el 100%
        // no revienta y el 30% ya se nota ligero.
        let punto = min(max(controles.intensidad, 0), 1)
        let fuerza = CGFloat(pow(Double(punto), 1.3) * 0.85)

        var a = afinado(ajuste(preset))

        // Lo que trae la camara de fabrica (fuga y grano) se apaga junto con
        // la intensidad. Lo que muevas a mano se queda como lo pusiste.
        a.rayones = controles.rayones ?? (a.rayones * fuerza)
        a.fuga = controles.fuga ?? (a.fuga * fuerza)
        a.grano = controles.grano ?? (a.grano * fuerza)

        return (a, fuerza)
    }

    /// Acomodo fino del look: los valores mas duros se acercan un poco al
    /// centro y la viñeta baja tantito, para que ninguna camara se vea
    /// exagerada. Las camaras suaves se quedan casi igual.
    private static func afinado(_ original: AjusteFoto) -> AjusteFoto {
        var a = original

        // La vision nocturna se deja cruda a proposito: es dura, con los
        // negros aplastados y las luces reventadas. Si la suavizamos, deja
        // de parecer una videocamara de noche.
        if a.vision > 0 {
            a.vineta = min(a.vineta, 1)
            return a
        }

        a.temperatura = 6500 + (a.temperatura - 6500) * 0.85
        a.saturacion = a.saturacion > 1
            ? 1 + (a.saturacion - 1) * 0.8
            : 1 - (1 - a.saturacion) * 0.92
        a.contraste = a.contraste > 1
            ? 1 + (a.contraste - 1) * 0.8
            : 1 - (1 - a.contraste) * 0.92
        a.vineta *= 0.85

        return a
    }

    /// Mezcla el look con la foto original: 0 = original, 1 = look completo.
    private static func mezclar(
        _ filtrada: CIImage,
        con original: CIImage,
        cantidad: CGFloat
    ) -> CIImage? {
        let f = CIFilter.dissolveTransition()
        f.inputImage = original
        f.targetImage = filtrada
        f.time = Float(min(max(cantidad, 0), 1))
        return f.outputImage
    }

    // MARK: - Tabla de looks

    static func ajuste(_ preset: FilterPreset) -> AjusteFoto {
        var a = AjusteFoto()

        switch preset {
        case .original:
            break

        // ---- clasicas ----
        case .portra:
            a.temperatura = 7100; a.saturacion = 1.02; a.contraste = 0.97
            a.desvanecido = 0.02; a.grano = 0.06; a.vineta = 0.3

        case .superia:
            a.temperatura = 6600; a.saturacion = 1.16; a.contraste = 1.08
            a.grano = 0.09; a.vineta = 0.35

        case .kodachrome:
            a.temperatura = 7400; a.saturacion = 1.25; a.contraste = 1.12
            a.grano = 0.05; a.vineta = 0.25

        case .instColor:
            a.temperatura = 8000; a.saturacion = 1.15; a.contraste = 0.95
            a.desvanecido = 0.03; a.vineta = 0.3

        case .dazzClassic:
            // D Classic: crema calida, negros levantados y grano grueso,
            // como el revelado de DazzCam.
            a.temperatura = 7000; a.tinte = 2; a.saturacion = 1.0
            a.contraste = 0.95; a.brillo = 0.012
            a.desvanecido = 0.045; a.grano = 0.085; a.vineta = 0.22

        // ---- vintage ----
        case .cinestill:
            a.temperatura = 5400; a.tinte = -8; a.saturacion = 1.1
            a.contraste = 1.05; a.desvanecido = 0.03; a.grano = 0.1; a.vineta = 0.3

        case .hp5:
            a.blancoYNegro = true; a.contraste = 1.2; a.grano = 0.14; a.vineta = 0.4

        case .lomo:
            a.saturacion = 1.35; a.contraste = 1.2; a.vineta = 0.85; a.grano = 0.1

        case .crossProcess:
            a.temperatura = 6000; a.tinte = 15; a.saturacion = 1.3
            a.contraste = 1.25; a.desvanecido = 0.05

        case .bleachBypass:
            a.saturacion = 0.45; a.contraste = 1.35; a.grano = 0.08

        case .faded90s:
            a.temperatura = 7200; a.saturacion = 0.75; a.contraste = 0.85
            a.desvanecido = 0.1; a.grano = 0.08

        case .copper:
            a.temperatura = 8500; a.tinte = 8; a.saturacion = 1.2
            a.contraste = 1.12; a.grano = 0.07

        case .kodakGold:
            a.temperatura = 7600; a.saturacion = 1.12; a.contraste = 1.05
            a.desvanecido = 0.02; a.grano = 0.08; a.vineta = 0.28

        case .ektar100:
            a.temperatura = 6800; a.saturacion = 1.25; a.contraste = 1.15
            a.grano = 0.03; a.vineta = 0.2

        case .fujiPro400:
            a.temperatura = 7000; a.tinte = -5; a.saturacion = 1.05
            a.contraste = 0.95; a.desvanecido = 0.03; a.grano = 0.06; a.vineta = 0.22

        case .delta3200:
            a.blancoYNegro = true; a.contraste = 1.25; a.grano = 0.2; a.vineta = 0.35

        case .agfaVista:
            a.temperatura = 7300; a.saturacion = 1.18; a.contraste = 1.05
            a.grano = 0.1; a.vineta = 0.3

        // ---- polaroid / instantanea ----
        case .polaroid600:
            a.temperatura = 7800; a.saturacion = 0.85; a.contraste = 0.9
            a.desvanecido = 0.06; a.vineta = 0.5; a.grano = 0.05

        case .sx70:
            a.temperatura = 7500; a.saturacion = 0.9; a.contraste = 1.0
            a.desvanecido = 0.05; a.vineta = 0.35; a.grano = 0.06

        case .instaxMini:
            a.temperatura = 8000; a.saturacion = 1.1; a.contraste = 0.88
            a.desvanecido = 0.08; a.vineta = 0.2; a.grano = 0.04

        case .instaxWide:
            a.temperatura = 7000; a.saturacion = 1.0; a.contraste = 0.92
            a.desvanecido = 0.07; a.vineta = 0.25; a.grano = 0.05

        case .polaroidFrio:
            a.temperatura = 5600; a.tinte = -6; a.saturacion = 0.8
            a.contraste = 0.95; a.desvanecido = 0.07; a.vineta = 0.55; a.grano = 0.06

        case .polaroidNoir:
            a.blancoYNegro = true; a.contraste = 1.05; a.desvanecido = 0.05
            a.vineta = 0.6; a.grano = 0.08

        // ---- underground ----
        case .vhs:
            a.temperatura = 6800; a.tinte = -10; a.saturacion = 0.9
            a.contraste = 0.9; a.desvanecido = 0.08; a.grano = 0.15

        case .d3d:
            a.temperatura = 6200; a.saturacion = 1.2; a.contraste = 1.15
            a.vineta = 0.5; a.grano = 0.12

        case .tealNight:
            a.temperatura = 5200; a.tinte = -12; a.saturacion = 1.1
            a.contraste = 1.1; a.vineta = 0.45; a.grano = 0.1

        case .warmFlash:
            a.temperatura = 8200; a.saturacion = 1.1; a.contraste = 1.05
            a.desvanecido = 0.02; a.vineta = 0.3

        case .noir:
            a.blancoYNegro = true; a.contraste = 1.45; a.vineta = 0.8; a.grano = 0.1

        case .vaporwave:
            a.temperatura = 6000; a.tinte = 25; a.saturacion = 1.4
            a.contraste = 1.05; a.desvanecido = 0.04; a.vineta = 0.3

        case .chatarraCCD:
            a.temperatura = 6300; a.saturacion = 1.3; a.contraste = 1.2
            a.grano = 0.18; a.vineta = 0.3

        // ---- agregadas en la v1.4 ----
        case .contaxT2:
            a.temperatura = 7000; a.saturacion = 1.06; a.contraste = 1.08
            a.grano = 0.06; a.vineta = 0.3

        case .goldenHour:
            // Atardecer dorado, pero con la imagen limpia: sin neblina.
            a.temperatura = 8000; a.tinte = 4; a.saturacion = 1.12
            a.contraste = 1.0; a.brillo = 0.008
            a.curva = [0.03, 0.27, 0.52, 0.79, 1.0]
            a.grano = 0.06; a.vineta = 0.2
            a.halacion = 0.14

        case .ultramax:
            a.temperatura = 7200; a.saturacion = 1.15; a.contraste = 1.06
            a.grano = 0.09; a.vineta = 0.3

        case .fujiC200:
            a.temperatura = 6900; a.tinte = -4; a.saturacion = 1.08
            a.contraste = 1.0; a.desvanecido = 0.03; a.grano = 0.08; a.vineta = 0.25

        case .provia:
            a.temperatura = 6600; a.tinte = -3; a.saturacion = 1.12
            a.contraste = 1.1; a.grano = 0.03; a.vineta = 0.18

        case .velvia:
            a.temperatura = 6500; a.tinte = -6; a.saturacion = 1.45
            a.contraste = 1.18; a.grano = 0.03; a.vineta = 0.25

        case .triX:
            a.blancoYNegro = true; a.contraste = 1.28; a.grano = 0.16; a.vineta = 0.35

        case .tmax:
            a.blancoYNegro = true; a.contraste = 1.35; a.grano = 0.22; a.vineta = 0.3

        case .cinestill50d:
            a.temperatura = 6200; a.tinte = 4; a.saturacion = 1.1
            a.contraste = 1.08; a.grano = 0.05; a.vineta = 0.2

        case .ektachrome:
            a.temperatura = 6800; a.saturacion = 1.2; a.contraste = 1.12
            a.grano = 0.04; a.vineta = 0.2

        case .disposable:
            a.temperatura = 7600; a.saturacion = 1.05; a.contraste = 0.95
            a.desvanecido = 0.08; a.grano = 0.12; a.vineta = 0.55

        case .sepiaViejo:
            a.temperatura = 8200; a.saturacion = 0.5; a.contraste = 1.1
            a.desvanecido = 0.12; a.grano = 0.18; a.vineta = 0.7

        case .polaroidGo:
            a.temperatura = 7700; a.saturacion = 0.88; a.contraste = 0.92
            a.desvanecido = 0.06; a.vineta = 0.45; a.grano = 0.05

        case .instaxMono:
            a.blancoYNegro = true; a.contraste = 0.95; a.desvanecido = 0.07
            a.vineta = 0.25; a.grano = 0.06

        case .y2kDigi:
            a.temperatura = 6400; a.tinte = 3; a.saturacion = 1.25
            a.contraste = 1.05; a.grano = 0.12; a.vineta = 0.2

        // ---- v1.7: Framed, ISM, OldRoll y Tezza ----
        case .framedSoft:
            a.temperatura = 6900; a.saturacion = 0.92; a.contraste = 0.92
            a.desvanecido = 0.07; a.grano = 0.05; a.vineta = 0.18

        case .framedFade:
            a.temperatura = 7000; a.saturacion = 0.78; a.contraste = 0.85
            a.desvanecido = 0.12; a.grano = 0.09; a.vineta = 0.3

        case .ismPastel:
            a.temperatura = 7200; a.tinte = 6; a.saturacion = 0.85
            a.contraste = 0.9; a.desvanecido = 0.09; a.grano = 0.06; a.vineta = 0.2

        case .ismCream:
            a.temperatura = 7700; a.saturacion = 0.9; a.contraste = 0.94
            a.desvanecido = 0.06; a.grano = 0.06; a.vineta = 0.22

        case .ismNight:
            a.temperatura = 5600; a.tinte = -10; a.saturacion = 1.15
            a.contraste = 1.15; a.grano = 0.14; a.vineta = 0.55

        case .oldRoll35:
            a.temperatura = 7500; a.saturacion = 1.06; a.contraste = 1.06
            a.desvanecido = 0.04; a.grano = 0.1; a.vineta = 0.32

        case .oldRollFlash:
            a.temperatura = 8200; a.saturacion = 1.05; a.contraste = 1.1
            a.brillo = 0.04; a.grano = 0.08; a.vineta = 0.45

        case .oldRoll8:
            a.temperatura = 7800; a.saturacion = 0.85; a.contraste = 0.95
            a.desvanecido = 0.08; a.grano = 0.2; a.vineta = 0.6

        case .oldRollInstant:
            a.temperatura = 7000; a.tinte = -4; a.saturacion = 0.92
            a.contraste = 0.9; a.desvanecido = 0.07; a.grano = 0.07; a.vineta = 0.45

        case .tezzaClean:
            a.temperatura = 7400; a.saturacion = 1.02; a.contraste = 1.04
            a.desvanecido = 0.03; a.grano = 0.03; a.vineta = 0.15

        case .tezzaWarm:
            a.temperatura = 8000; a.saturacion = 1.08; a.contraste = 1.02
            a.desvanecido = 0.04; a.grano = 0.05; a.vineta = 0.2

        case .tezzaGrain:
            a.temperatura = 7200; a.saturacion = 1.0; a.contraste = 1.0
            a.desvanecido = 0.06; a.grano = 0.18; a.vineta = 0.35

        case .tezzaPolaroid:
            a.temperatura = 7800; a.saturacion = 0.9; a.contraste = 0.9
            a.desvanecido = 0.08; a.vineta = 0.5; a.grano = 0.06

        case .sakura:
            a.temperatura = 7300; a.tinte = 12; a.saturacion = 1.05
            a.contraste = 0.92; a.desvanecido = 0.07; a.grano = 0.05; a.vineta = 0.18

        case .latte:
            a.temperatura = 7900; a.tinte = 4; a.saturacion = 0.88
            a.contraste = 0.9; a.desvanecido = 0.08; a.grano = 0.06; a.vineta = 0.2

        case .oceanFade:
            a.temperatura = 6000; a.tinte = -8; a.saturacion = 0.95
            a.contraste = 0.92; a.desvanecido = 0.08; a.grano = 0.05; a.vineta = 0.25

        case .cinemaTeal:
            a.temperatura = 6400; a.tinte = -6; a.saturacion = 1.1
            a.contraste = 1.18; a.desvanecido = 0.02; a.grano = 0.06; a.vineta = 0.3

        case .disco:
            a.temperatura = 6800; a.tinte = 18; a.saturacion = 1.35
            a.contraste = 1.15; a.grano = 0.1; a.vineta = 0.35

        case .milk:
            a.temperatura = 7500; a.saturacion = 0.8; a.contraste = 0.82
            a.brillo = 0.03; a.desvanecido = 0.14; a.grano = 0.04; a.vineta = 0.15

        case .neonDream:
            a.temperatura = 6200; a.tinte = 22; a.saturacion = 1.4
            a.contraste = 1.1; a.desvanecido = 0.05; a.grano = 0.12; a.vineta = 0.35

        // ---- v1.15: SWAG, Jackboys y Riviera ----
        case .swagLive:
            // Flash directo de noche, calido y un poco pasado de luz.
            a.temperatura = 7900; a.tinte = 6; a.saturacion = 1.02
            a.contraste = 0.92; a.brillo = 0.05
            a.desvanecido = 0.055; a.grano = 0.11; a.vineta = 0.38

        case .jackboys:
            // Noche cerrada, sombras frias y rojos apagados. Sucio y oscuro.
            a.temperatura = 5700; a.tinte = -9; a.saturacion = 0.82
            a.contraste = 1.28; a.brillo = -0.03
            a.desvanecido = 0.02; a.grano = 0.17; a.vineta = 0.62

        case .riviera92:
            // Revista de vacaciones de los 90: crema, lavado y suave.
            a.temperatura = 7600; a.tinte = 3; a.saturacion = 0.86
            a.contraste = 0.88; a.brillo = 0.02
            a.desvanecido = 0.1; a.grano = 0.07; a.vineta = 0.3

        // ---- v1.17: camaras de rollo ----
        case .yashicaT4:
            a.temperatura = 7000; a.saturacion = 1.05; a.contraste = 1.06
            a.grano = 0.07; a.vineta = 0.24

        case .olympusMju:
            a.temperatura = 7200; a.saturacion = 1.02; a.contraste = 0.96
            a.desvanecido = 0.03; a.grano = 0.06; a.vineta = 0.2

        case .canonSure:
            a.temperatura = 8000; a.saturacion = 1.08; a.contraste = 1.05
            a.brillo = 0.03; a.grano = 0.09; a.vineta = 0.34

        case .nikonFm2:
            a.temperatura = 6700; a.saturacion = 1.18; a.contraste = 1.18
            a.grano = 0.08; a.vineta = 0.28

        case .praktica:
            a.temperatura = 6200; a.tinte = -6; a.saturacion = 0.95
            a.contraste = 1.1; a.desvanecido = 0.03
            a.grano = 0.11; a.vineta = 0.4

        case .zenit12:
            a.temperatura = 5800; a.tinte = -8; a.saturacion = 0.88
            a.contraste = 1.22; a.grano = 0.13; a.vineta = 0.5

        case .kodakVR:
            a.temperatura = 7800; a.saturacion = 1.12; a.contraste = 1.03
            a.desvanecido = 0.04; a.grano = 0.1; a.vineta = 0.32

        case .agfaOptima:
            a.temperatura = 7400; a.tinte = 5; a.saturacion = 1.06
            a.contraste = 0.98; a.desvanecido = 0.05
            a.grano = 0.09; a.vineta = 0.28

        // ---- v1.24: desechables ----
        case .funSaver:
            // Flash de una sola vez: calido, contrastado y con las esquinas
            // quemadas. El amarillo Kodak se nota.
            a.temperatura = 7800; a.tinte = 4; a.saturacion = 1.1
            a.contraste = 1.06; a.brillo = 0.03
            a.desvanecido = 0.03; a.grano = 0.14; a.vineta = 0.55

        case .quickSnap:
            // Fuji desechable: verde en las sombras y flash duro.
            a.temperatura = 7000; a.tinte = -6; a.saturacion = 1.08
            a.contraste = 1.1; a.brillo = 0.02
            a.grano = 0.13; a.vineta = 0.5

        case .sprite35:
            // B y N barato, muy granoso, con poco rango.
            a.blancoYNegro = true; a.contraste = 1.2
            a.grano = 0.22; a.vineta = 0.52

        case .leBox:
            // Agfa de fiesta: rojos vivos y flash directo.
            a.temperatura = 7600; a.tinte = 8; a.saturacion = 1.16
            a.contraste = 1.02; a.brillo = 0.04
            a.desvanecido = 0.04; a.grano = 0.12; a.vineta = 0.42

        case .simpleUse:
            // Lomo recargable: contraste alto y color pasado.
            a.temperatura = 7200; a.tinte = -4; a.saturacion = 1.22
            a.contraste = 1.14; a.grano = 0.12; a.vineta = 0.48

        case .sportDesechable:
            // Sumergible: frio, lavado y con el azul del agua.
            a.temperatura = 6100; a.tinte = -10; a.saturacion = 1.05
            a.contraste = 1.0; a.desvanecido = 0.05
            a.grano = 0.11; a.vineta = 0.4

        // ---- v1.24: los 2000 ----
        case .powerShot:
            // Canon de los 2000: color honesto y un pelin de ruido.
            a.temperatura = 6700; a.saturacion = 1.12; a.contraste = 1.06
            a.grano = 0.08; a.vineta = 0.2

        case .cyberShot:
            // Sony: azules frios, verdes electricos y flash quemado.
            a.temperatura = 6100; a.tinte = -4; a.saturacion = 1.28
            a.contraste = 1.12; a.brillo = 0.02; a.grano = 0.1
            a.vineta = 0.24

        case .coolpix:
            // Nikon: mas neutra, casi de estudio.
            a.temperatura = 6500; a.saturacion = 1.06; a.contraste = 1.08
            a.grano = 0.07; a.vineta = 0.18

        case .exilim:
            // Casio: saturacion de folleto y blancos frios.
            a.temperatura = 6300; a.tinte = 3; a.saturacion = 1.22
            a.contraste = 1.04; a.grano = 0.09; a.vineta = 0.2

        case .lumix:
            // Panasonic: verdes ricos y sombras suaves.
            a.temperatura = 6600; a.tinte = -3; a.saturacion = 1.14
            a.contraste = 1.02; a.grano = 0.07; a.vineta = 0.2

        case .easyShare:
            // Kodak facil: calido, alegre y sin miedo al flash.
            a.temperatura = 7500; a.saturacion = 1.18; a.contraste = 1.02
            a.brillo = 0.03; a.grano = 0.09; a.vineta = 0.26

        case .handycam:
            // Videocamara MiniDV: contraste bajo, color lavado y ruido.
            a.temperatura = 6800; a.tinte = -5; a.saturacion = 0.92
            a.contraste = 0.94; a.brillo = 0.02
            a.desvanecido = 0.06; a.grano = 0.16; a.vineta = 0.3

        // ---- v1.24: vision nocturna ----
        case .nightshotVideo:
            // Verde, negro y luces reventadas. La videocamara de noche.
            a.contraste = 1.18; a.brillo = -0.06
            a.vision = 1; a.halacion = 1
            a.grano = 0.42; a.vineta = 1.0

        case .nightshotFoto:
            // La misma camara, pero para foto.
            a.contraste = 1.15; a.brillo = -0.04
            a.vision = 1; a.halacion = 0.95
            a.grano = 0.34; a.vineta = 0.95

        // ---- v1.25.19: looks de Prequel y Tezza ----
        case .g7x:
            // Canon G7X: color limpio, un pelin calido y contraste de
            // compacta buena. Casi no se nota el grano.
            a.temperatura = 7000; a.tinte = 2; a.saturacion = 1.1
            a.contraste = 1.04; a.nitidez = 0.4
            a.curva = [0.0, 0.24, 0.5, 0.77, 1.0]
            a.grano = 0.02; a.vineta = 0.16

        case .digitalFlash:
            // Flash directo de compacta: el sujeto queda bien iluminado, el
            // fondo se cae y los blancos se van un poco al frio.
            a.temperatura = 6100; a.tinte = -2; a.saturacion = 1.0
            a.contraste = 1.1; a.brillo = 0.005
            a.curva = [0.0, 0.17, 0.5, 0.85, 1.0]
            a.flash = 0.3; a.nitidez = 0.3
            a.grano = 0.05; a.vineta = 0.5

        case .tezza99:
            // Videocamara de 1999: calido, grano grueso y colores que se
            // separan en los bordes, pero la imagen se ve entera.
            a.temperatura = 7600; a.tinte = 4; a.saturacion = 1.02
            a.contraste = 1.0; a.brillo = 0.005
            a.curva = [0.03, 0.25, 0.51, 0.8, 0.98]
            a.grano = 0.17; a.vineta = 0.3
            a.halacion = 0.16; a.aberracion = 0.4; a.suavidad = 0.16
        }

        // Rayones de pelicula: apagados por defecto. Se suben a mano en el
        // editor si el usuario los quiere; asi ninguna camara los trae fake.
        a.rayones = 0

        // Fugas de luz: la camara decide donde y cuanto (0 a 100%).
        switch preset {
        case .oldRollFlash:
            a.fuga = 0.65
        case .disposable:
            a.fuga = 0.6
        case .oldRoll8:
            a.fuga = 0.5
        case .disco:
            a.fuga = 0.5
        case .neonDream:
            a.fuga = 0.45
        case .swagLive:
            a.fuga = 0.35
        case .jackboys:
            a.fuga = 0.28
        case .riviera92:
            a.fuga = 0.22
        case .dazzClassic:
            a.fuga = 0.18
        case .canonSure, .kodakVR:
            a.fuga = 0.32
        case .zenit12:
            a.fuga = 0.2
        case .praktica, .yashicaT4, .agfaOptima:
            a.fuga = 0.14
        case .olympusMju:
            a.fuga = 0.12
        case .nikonFm2:
            a.fuga = 0.1
        case .chatarraCCD:
            a.fuga = 0.35
        case .funSaver, .quickSnap, .leBox, .sportDesechable:
            a.fuga = 0.42
        case .simpleUse:
            a.fuga = 0.5
        case .sprite35:
            a.fuga = 0.28
        case .framedFade:
            a.fuga = 0.35
        case .vhs, .oldRoll35:
            a.fuga = 0.3
        case .y2kDigi, .d3d, .tezzaPolaroid:
            a.fuga = 0.25
        case .goldenHour:
            a.fuga = 0.12
        case .polaroid600, .sx70, .instColor:
            a.fuga = 0.2
        default:
            a.fuga = 0
        }

        return a
    }

    // MARK: - Cadena generica

    private static func aplicarLook(
        _ a: AjusteFoto,
        a imagen: CIImage
    ) -> CIImage? {
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

        // 2a. curva de tono: da el caracter de la camara sin lavar la foto.
        if let puntos = a.curva, puntos.count == 5 {
            let f = CIFilter.toneCurve()
            f.inputImage = actual
            f.point0 = CGPoint(x: 0, y: puntos[0])
            f.point1 = CGPoint(x: 0.25, y: puntos[1])
            f.point2 = CGPoint(x: 0.5, y: puntos[2])
            f.point3 = CGPoint(x: 0.75, y: puntos[3])
            f.point4 = CGPoint(x: 1, y: puntos[4])
            if let salida = f.outputImage { actual = salida }
        }

        // 2b. flash directo: el centro se ilumina y las orillas se caen.
        if a.flash > 0 {
            let e = imagen.extent
            let gradiente = CIFilter.radialGradient()
            gradiente.center = CGPoint(x: e.midX, y: e.midY + e.height * 0.06)
            gradiente.radius0 = 0
            gradiente.radius1 = Float(max(e.width, e.height) * 0.78)
            gradiente.color0 = CIColor(red: 1, green: 0.98, blue: 0.95, alpha: 1)
            gradiente.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 1)

            if let capa = gradiente.outputImage?.cropped(to: e) {
                let fuerza = min(max(a.flash, 0), 1)
                let control = CIFilter.colorMatrix()
                control.inputImage = capa
                control.rVector = CIVector(x: fuerza, y: 0, z: 0, w: 0)
                control.gVector = CIVector(x: 0, y: fuerza, z: 0, w: 0)
                control.bVector = CIVector(x: 0, y: 0, z: fuerza, w: 0)
                control.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

                if let luz = control.outputImage {
                    let mezcla = CIFilter.screenBlendMode()
                    mezcla.inputImage = luz
                    mezcla.backgroundImage = actual
                    if let salida = mezcla.outputImage { actual = salida }
                }
            }
        }

        // 2c. optica blanda: la imagen pierde filo, como una videocamara.
        if a.suavidad > 0 {
            let f = CIFilter.gaussianBlur()
            f.inputImage = actual.clampedToExtent()
            f.radius = Float(max(imagen.extent.width * 0.0016 * a.suavidad, 0.6))
            if let salida = f.outputImage?.cropped(to: imagen.extent) {
                actual = salida
            }
        }

        // 2d. separacion de color: el rojo se abre y el azul se cierra un
        //     pelo alrededor del centro, como en una optica vieja.
        if a.aberracion > 0 {
            let e = imagen.extent
            let corrimiento = min(max(a.aberracion, 0), 1) * 0.005

            func canal(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CIImage? {
                let f = CIFilter.colorMatrix()
                f.inputImage = actual
                f.rVector = CIVector(x: r, y: 0, z: 0, w: 0)
                f.gVector = CIVector(x: 0, y: g, z: 0, w: 0)
                f.bVector = CIVector(x: 0, y: 0, z: b, w: 0)
                f.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
                return f.outputImage
            }

            func escalar(_ capa: CIImage, _ escala: CGFloat) -> CIImage {
                let giro = CGAffineTransform(translationX: e.midX, y: e.midY)
                    .concatenating(CGAffineTransform(scaleX: escala, y: escala))
                    .concatenating(CGAffineTransform(translationX: -e.midX, y: -e.midY))
                return capa.clampedToExtent().transformed(by: giro)
            }

            if let rojo = canal(1, 0, 0), let verde = canal(0, 1, 0),
               let azul = canal(0, 0, 1) {

                let rojoAbierto = escalar(rojo, 1 + corrimiento)
                let azulCerrado = escalar(azul, 1 - corrimiento)

                var suma = verde
                let uno = CIFilter.additionCompositing()
                uno.inputImage = rojoAbierto
                uno.backgroundImage = suma
                if let juntos = uno.outputImage {
                    suma = juntos
                }

                let dos = CIFilter.additionCompositing()
                dos.inputImage = azulCerrado
                dos.backgroundImage = suma
                if let juntos = dos.outputImage?.cropped(to: e) {
                    suma = juntos
                }

                actual = suma
            }
        }

        // 2e. nitidez: devuelve el filo que perdio la optica.
        if a.nitidez > 0 {
            let f = CIFilter.sharpenLuminance()
            f.inputImage = actual
            f.sharpness = Float(min(max(a.nitidez, 0), 2))
            if let salida = f.outputImage?.cropped(to: imagen.extent) {
                actual = salida
            }
        }

        // 3. blanco y negro
        if a.blancoYNegro {
            let f = CIFilter.photoEffectMono()
            f.inputImage = actual
            if let salida = f.outputImage { actual = salida }
        }

        // 3b. vision nocturna: intensificador de luz, verde apagado de los
        //     2000, negros aplastados y luces que revientan. El verde no es
        //     fosforo puro: es casi un blanco y negro con un tinte salvia,
        //     como en las videocamaras Sony de noche.
        if a.vision > 0 {
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = actual

            if let gris = mono.outputImage {
                let tinte = CIFilter.colorMatrix()
                tinte.inputImage = gris
                // Tinte suave: el verde apenas se separa del gris.
                tinte.rVector = CIVector(x: 0.80, y: 0, z: 0, w: 0)
                tinte.gVector = CIVector(x: 0, y: 0.88, z: 0, w: 0)
                tinte.bVector = CIVector(x: 0, y: 0, z: 0.82, w: 0)
                tinte.biasVector = CIVector(x: 0.012, y: 0.014, z: 0.012, w: 0)

                if let verde = tinte.outputImage {
                    let curva = CIFilter.toneCurve()
                    curva.inputImage = verde
                    // Negros aplastados, medios con cuerpo y luces que se
                    // van a blanco: asi el verde no queda plano ni falso.
                    curva.point0 = CGPoint(x: 0.0, y: 0.0)
                    curva.point1 = CGPoint(x: 0.16, y: 0.035)
                    curva.point2 = CGPoint(x: 0.46, y: 0.50)
                    curva.point3 = CGPoint(x: 0.72, y: 0.93)
                    curva.point4 = CGPoint(x: 1.0, y: 1.0)

                    let crudo = curva.outputImage ?? verde
                    let cantidad = min(max(a.vision, 0), 1)

                    if cantidad >= 0.999 {
                        actual = crudo
                    } else if let mezcla = mezclar(crudo, con: actual, cantidad: cantidad) {
                        actual = mezcla
                    } else {
                        actual = crudo
                    }
                }
            }
        }

        // 3c. resplandor: las luces se derraman alrededor, como en el visor
        //     de una videocamara de noche.
        if a.halacion > 0 {
            let f = CIFilter.bloom()
            f.inputImage = actual
            f.intensity = Float(min(a.halacion, 1) * 1.45)
            f.radius = Float(max(imagen.extent.width * 0.018, 7))
            if let salida = f.outputImage?.cropped(to: imagen.extent) {
                actual = salida
            }
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

        return actual
    }

    /// Grano, rayones y fuga. Va aparte del look de color para que bajar la
    /// intensidad del filtro no borre el dano de la pelicula.
    private static func aplicarTextura(
        _ a: AjusteFoto,
        a imagen: CIImage,
        semilla: UInt64,
        momento: UInt64
    ) -> CIImage? {
        var actual = imagen

        // Cada efecto trae su propio dado. Asi mover los rayones no cambia
        // donde sale la fuga, ni al reves.
        var azarRayones = Azar(semilla ^ 0x9E37_79B9_7F4A_7C15)
        var azarFuga = Azar(semilla ^ 0xD1B5_4A32_D192_ED03)

        // 6. grano
        if a.grano > 0, let conGrano = grano(actual, cantidad: a.grano) {
            actual = conGrano
        }

        // 7. Pelos y polvo del negativo. Cada toma estrena patron. En video
        //    los pelos saltan, parpadean y a veces desaparecen, como cuando
        //    el negativo va suelto dentro de una camara vieja.
        if a.rayones > 0 {
            let fuerzaBase = min(
                max(a.rayones * azarRayones.valor(0.8...1.25), 0),
                1
            )
            let desfaseBase = CGPoint(
                x: azarRayones.valor(0...2048),
                y: azarRayones.valor(0...2048)
            )
            let espejo = azarRayones.entero(2) == 1

            if momento == 0 {
                // Foto: un solo patron, quieto.
                if let capa = rayones(
                    actual,
                    cantidad: fuerzaBase,
                    desfase: desfaseBase,
                    espejo: espejo
                ) {
                    actual = capa
                }
            } else {
                // Video: el negativo se sacude de verdad. Salto vertical
                // fuerte, temblor lateral y tres capas de otras zonas del
                // patron: asi entran pelos nuevos en lugares distintos.
                let cuadro = momento / 3
                var temblor = Azar(semilla &+ (cuadro &* 0x9E37_79B9_7F4A_7C15))
                let salto = CGPoint(
                    x: temblor.valor(-70...70),
                    y: temblor.valor(-320...320)
                )
                let parpadeo = temblor.valor(0.45...1.15)
                let apagado: CGFloat = temblor.valor(0...1) < 0.08 ? 0.2 : 1
                let fuerza = min(max(fuerzaBase * parpadeo * apagado, 0), 1)

                if let capa = rayones(
                    actual,
                    cantidad: fuerza,
                    desfase: CGPoint(
                        x: desfaseBase.x + salto.x,
                        y: desfaseBase.y + salto.y
                    ),
                    espejo: espejo
                ) {
                    actual = capa
                }

                // Dos capas mas, cada una con su propia zona y su propio
                // parpadeo, para que no se vean siempre los mismos pelos.
                for indice in 0..<3 {
                    let extra = temblor.valor(0.15...0.50)
                    guard extra > 0.18 else { continue }

                    if let capa = rayones(
                        actual,
                        cantidad: min(extra * fuerzaBase, 1),
                        desfase: CGPoint(
                            x: desfaseBase.x + temblor.valor(-1100...1100),
                            y: desfaseBase.y + temblor.valor(-2000...2000)
                        ),
                        espejo: indice == 0 ? !espejo : espejo
                    ) {
                        actual = capa
                    }
                }
            }
        }

        // 8. fuga de luz: cada foto elige punto de entrada, forma, color y fuerza.
        if a.fuga > 0 {
            let tipo = azarFuga.entero(3)
            let posicion = azarFuga.valor(0...1)
            let pulso = momento > 0
                ? 0.88 + 0.12 * CGFloat(sin(Double(momento / 2) * 0.9))
                : 1
            // El control responde suave abajo: al 10% apenas se insinua y
            // hasta arriba se pone fuerte, como una fuga de verdad.
            let curva = CGFloat(pow(Double(a.fuga), 1.65))
            let fuerza = min(
                max(curva * azarFuga.valor(0.75...1.15) * pulso, 0),
                1
            )
            let radioBase = azarFuga.valor(0.32...0.95)
            let radio = momento > 0
                ? radioBase * (0.90 + 0.10 * CGFloat(sin(Double(momento) * 0.031)))
                : radioBase
            let corrimiento = CGPoint(
                x: azarFuga.valor(-0.18...0.18),
                y: azarFuga.valor(-0.18...0.18)
            )
            let color = azarFuga.entero(coloresFuga.count)
            let inclinacion = azarFuga.valor(-1.0...1.0)

            // En video la luz recorre el borde, como cuando mueves la
            // camara. En foto se queda donde le toco.
            let desvio = momento > 0
                ? CGFloat(sin(Double(momento) * 0.02)) * 0.18
                : 0

            if let conFuga = fuga(
                actual,
                cantidad: fuerza,
                tipo: tipo,
                posicion: posicion,
                radio: radio,
                corrimiento: corrimiento,
                color: color,
                inclinacion: inclinacion,
                desvio: desvio
            ) {
                actual = conFuga
            }
        }

        return actual
    }

    // MARK: - Fuga de luz

    /// Colores de fuga que se ven en pelicula: naranja, rojo, rosa, dorado
    /// y crema. Cada foto elige uno al azar.
    private static let coloresFuga: [CIColor] = [
        CIColor(red: 1.0, green: 0.45, blue: 0.12),
        CIColor(red: 1.0, green: 0.24, blue: 0.08),
        CIColor(red: 1.0, green: 0.36, blue: 0.40),
        CIColor(red: 1.0, green: 0.66, blue: 0.20),
        CIColor(red: 1.0, green: 0.84, blue: 0.58)
    ]

    /// La luz entra por cualquier punto del borde, no solo por las esquinas.
    /// Asi dos fotos seguidas nunca tienen la fuga en el mismo lugar.
    private static func fuga(
        _ imagen: CIImage,
        cantidad: CGFloat,
        tipo: Int,
        posicion: CGFloat,
        radio: CGFloat,
        corrimiento: CGPoint,
        color: Int,
        inclinacion: CGFloat,
        desvio: CGFloat
    ) -> CIImage? {
        let extent = imagen.extent
        let ancho = extent.width
        let alto = extent.height
        guard ancho > 0, alto > 0 else { return nil }

        let tono = coloresFuga[abs(color) % coloresFuga.count]
        let fuerza = min(max(cantidad, 0), 1)
        let mayor = max(ancho, alto)

        // Recorrido continuo por el borde: 0 = empieza arriba a la izquierda.
        var vuelta = posicion + desvio
        vuelta -= floor(vuelta)
        let perimetro = 2 * (ancho + alto)
        var recorrido = vuelta * perimetro

        var punto = CGPoint.zero
        var adentro = CGPoint.zero

        if recorrido < ancho {
            punto = CGPoint(x: extent.minX + recorrido, y: extent.maxY)
            adentro = CGPoint(x: 0, y: -1)
        } else if recorrido < ancho + alto {
            recorrido -= ancho
            punto = CGPoint(x: extent.maxX, y: extent.maxY - recorrido)
            adentro = CGPoint(x: -1, y: 0)
        } else if recorrido < 2 * ancho + alto {
            recorrido -= ancho + alto
            punto = CGPoint(x: extent.maxX - recorrido, y: extent.minY)
            adentro = CGPoint(x: 0, y: 1)
        } else {
            recorrido -= 2 * ancho + alto
            punto = CGPoint(x: extent.minX, y: extent.minY + recorrido)
            adentro = CGPoint(x: 1, y: 0)
        }

        punto.x += corrimiento.x * ancho * 0.12
        punto.y += corrimiento.y * alto * 0.12

        // El centro queda un poco afuera de la foto, para que la luz se
        // derrame hacia adentro.
        let centro = CGPoint(
            x: punto.x - adentro.x * mayor * 0.08,
            y: punto.y - adentro.y * mayor * 0.08
        )

        var crudo: CIImage?

        switch abs(tipo) % 3 {
        case 0:
            // Resplandor que entra por un punto del borde.
            let gradiente = CIFilter.radialGradient()
            gradiente.center = centro
            gradiente.radius0 = 0
            gradiente.radius1 = Float(mayor * radio)
            gradiente.color0 = tono
            gradiente.color1 = CIColor(red: 0, green: 0, blue: 0)
            crudo = gradiente.outputImage?.cropped(to: extent)

        case 1:
            // Franja ancha que entra desde ese punto hacia adentro.
            let gradiente = CIFilter.linearGradient()
            let banda = mayor * (0.18 + radio * 0.55)
            gradiente.point0 = CGPoint(
                x: punto.x - adentro.x * mayor * 0.14,
                y: punto.y - adentro.y * mayor * 0.14
            )
            gradiente.point1 = CGPoint(
                x: punto.x + adentro.x * banda,
                y: punto.y + adentro.y * banda
            )
            gradiente.color0 = tono
            gradiente.color1 = CIColor(red: 0, green: 0, blue: 0)
            crudo = gradiente.outputImage?.cropped(to: extent)

        default:
            // Banda diagonal, como cuando la luz cruza el objetivo.
            let gradiente = CIFilter.linearGradient()
            let y0 = extent.minY + alto * vuelta
            gradiente.point0 = CGPoint(
                x: extent.minX - ancho * 0.25,
                y: y0 + alto * inclinacion * 0.5
            )
            gradiente.point1 = CGPoint(
                x: extent.maxX + ancho * 0.25,
                y: y0 - alto * inclinacion * 0.5
            )
            gradiente.color0 = tono
            gradiente.color1 = CIColor(red: 0, green: 0, blue: 0)
            crudo = gradiente.outputImage?.cropped(to: extent)
        }

        guard let capa = crudo else { return nil }

        let control = CIFilter.colorMatrix()
        control.inputImage = capa
        control.rVector = CIVector(x: fuerza, y: 0, z: 0, w: 0)
        control.gVector = CIVector(x: 0, y: fuerza, z: 0, w: 0)
        control.bVector = CIVector(x: 0, y: 0, z: fuerza, w: 0)
        control.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let preparada = control.outputImage else { return nil }

        let mezcla = CIFilter.screenBlendMode()
        mezcla.inputImage = preparada
        mezcla.backgroundImage = imagen
        return mezcla.outputImage
    }

    // MARK: - Grano

    private static let ruidoBase: CIImage? = {
        let f = CIFilter.randomGenerator()
        return f.outputImage
    }()

    private static func grano(_ imagen: CIImage, cantidad: CGFloat) -> CIImage? {
        guard let ruido = ruidoBase?.cropped(to: imagen.extent) else { return nil }

        // ruido a gris
        let gris = CIFilter.colorMatrix()
        gris.inputImage = ruido
        gris.rVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        gris.gVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        gris.bVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        gris.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let grisSalida = gris.outputImage else { return nil }

        // transparencia = cantidad
        let transparencia = CIFilter.colorMatrix()
        transparencia.inputImage = grisSalida
        transparencia.aVector = CIVector(x: 0, y: 0, z: 0, w: cantidad)
        guard let capa = transparencia.outputImage else { return nil }

        let mezcla = CIFilter.softLightBlendMode()
        mezcla.inputImage = capa
        mezcla.backgroundImage = imagen
        return mezcla.outputImage
    }

    // MARK: - Rayones de pelicula

    /// El dano de una foto revelada: hebras blancas y oscuras con curvas
    /// simples, y polvo alargado. Formas sencillas, como un pelo de verdad.
    private static let rayonesTile: CIImage? = {
        let lado = 2048
        let espacio = CGColorSpaceCreateDeviceRGB()

        guard let contexto = CGContext(
            data: nil,
            width: lado,
            height: lado,
            bitsPerComponent: 8,
            bytesPerRow: lado * 4,
            space: espacio,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        contexto.clear(CGRect(x: 0, y: 0, width: lado, height: lado))
        contexto.setShouldAntialias(true)
        contexto.setLineCap(.round)
        contexto.setLineJoin(.round)

        let ancho = CGFloat(lado)
        let alto = CGFloat(lado)

        func claro(_ alfa: CGFloat) -> CGColor? {
            CGColor(
                colorSpace: espacio,
                components: [1, 0.985, 0.95, alfa]
            )
        }

        func oscuro(_ alfa: CGFloat) -> CGColor? {
            CGColor(
                colorSpace: espacio,
                components: [0.03, 0.02, 0.02, alfa]
            )
        }

        func trazar(_ puntos: [CGPoint], color: CGColor, grosor: CGFloat) {
            guard puntos.count > 1 else { return }

            contexto.setStrokeColor(color)
            contexto.setLineWidth(grosor)
            contexto.beginPath()
            contexto.move(to: puntos[0])

            if puntos.count == 2 {
                contexto.addLine(to: puntos[1])
            } else {
                // Curva suave por los puntos medios: nada de esquinas.
                for i in 1..<(puntos.count - 1) {
                    let medio = CGPoint(
                        x: (puntos[i].x + puntos[i + 1].x) / 2,
                        y: (puntos[i].y + puntos[i + 1].y) / 2
                    )
                    contexto.addQuadCurve(to: medio, control: puntos[i])
                }
                contexto.addLine(to: puntos[puntos.count - 1])
            }

            contexto.strokePath()
        }

        func paseo(
            pasos: ClosedRange<Int>,
            largo: ClosedRange<CGFloat>,
            giro: ClosedRange<CGFloat>
        ) -> [CGPoint] {
            var puntos: [CGPoint] = [CGPoint(
                x: CGFloat.random(in: 0..<ancho),
                y: CGFloat.random(in: 0..<alto)
            )]
            var angulo = CGFloat.random(in: 0...(2 * .pi))
            let cantidad = Int.random(in: pasos)
            let separacion: CGFloat = 12

            for _ in 0..<cantidad {
                var colocado = false

                // Prueba varios rumbos. Si todos se acercan al camino o se
                // salen del cuadro, la hebra termina ahi con la punta
                // abierta: nunca se cierra sobre si misma.
                for _ in 0..<10 {
                    let rumbo = angulo + CGFloat.random(in: giro)
                    let paso = CGFloat.random(in: largo)
                    let candidato = CGPoint(
                        x: puntos[puntos.count - 1].x + cos(rumbo) * paso,
                        y: puntos[puntos.count - 1].y + sin(rumbo) * paso
                    )

                    if candidato.x < 0 || candidato.x > ancho
                        || candidato.y < 0 || candidato.y > alto {
                        continue
                    }

                    var choca = false
                    let limite = puntos.count - 4

                    if limite > 0 {
                        for i in 0..<limite {
                            let dx = candidato.x - puntos[i].x
                            let dy = candidato.y - puntos[i].y

                            if dx * dx + dy * dy < separacion * separacion {
                                choca = true
                                break
                            }
                        }
                    }

                    if !choca {
                        puntos.append(candidato)
                        angulo = rumbo
                        colocado = true
                        break
                    }
                }

                if !colocado { break }
            }

            return puntos
        }

        // 1. Hebras blancas: rizadas y con curvas, como las de la foto.
        for _ in 0..<9 {
            let hebra = paseo(
                pasos: 8...70,
                largo: 3...10,
                giro: -0.85...0.85
            )
            let alfa = CGFloat.random(in: 0.09...0.24)
            let grosor = CGFloat.random(in: 0.8...1.9)

            if let color = claro(alfa * 0.40) {
                trazar(hebra, color: color, grosor: grosor * 2.6)
            }
            if let color = claro(alfa) {
                trazar(hebra, color: color, grosor: grosor)
            }
        }

        // 2. Hebras oscuras: largas, finas y apenas torcidas.
        for _ in 0..<4 {
            let hebra = paseo(
                pasos: 40...95,
                largo: 5...12,
                giro: -0.22...0.22
            )

            if let color = oscuro(CGFloat.random(in: 0.07...0.16)) {
                trazar(
                    hebra,
                    color: color,
                    grosor: CGFloat.random(in: 0.6...1.2)
                )
            }
        }

        // 3. Rayones: tramos cortos y quebrados, casi verticales. Nunca de
        //    lado a lado: en un negativo real el roce viene por partes.
        for _ in 0..<12 {
            let alfa = CGFloat.random(in: 0.05...0.19)
            let grosor = CGFloat.random(in: 0.5...1.3)
            let tramos = Int.random(in: 1...3)
            var punto = CGPoint(
                x: CGFloat.random(in: 0..<ancho),
                y: CGFloat.random(in: 0..<alto)
            )
            var angulo = .pi / 2 + CGFloat.random(in: -0.22...0.22)

            for _ in 0..<tramos {
                // A veces el rayon se corta y sigue mas arriba.
                if CGFloat.random(in: 0...1) < 0.2 { continue }

                let largo = CGFloat.random(in: 40...150)
                let fin = CGPoint(
                    x: punto.x + cos(angulo) * largo,
                    y: punto.y + sin(angulo) * largo
                )

                if let color = claro(alfa) {
                    contexto.setStrokeColor(color)
                    contexto.setLineWidth(grosor)
                    contexto.beginPath()
                    contexto.move(to: punto)
                    contexto.addLine(to: fin)
                    contexto.strokePath()
                }

                punto = fin
                angulo += CGFloat.random(in: -0.09...0.09)
            }
        }

        // 4. Polvo. Motas chiquitas, pelusas cortas, motas oscuras y alguna
        //    hebra fina de tela. Todo alargado: nunca circulos.

        // 4a. Motas finas de polvo claro.
        for _ in 0..<62 {
            let x = CGFloat.random(in: 0..<ancho)
            let y = CGFloat.random(in: 0..<alto)
            let largo = CGFloat.random(in: 0.8...2.6)
            let angulo = CGFloat.random(in: 0...(2 * .pi))

            if let color = claro(CGFloat.random(in: 0.05...0.18)) {
                contexto.setStrokeColor(color)
                contexto.setLineWidth(CGFloat.random(in: 0.4...0.9))
                contexto.beginPath()
                contexto.move(to: CGPoint(x: x, y: y))
                contexto.addLine(to: CGPoint(
                    x: x + cos(angulo) * largo,
                    y: y + sin(angulo) * largo
                ))
                contexto.strokePath()
            }
        }

        // 4b. Pelusas cortas con una curva suave.
        for _ in 0..<28 {
            let x = CGFloat.random(in: 0..<ancho)
            let y = CGFloat.random(in: 0..<alto)
            let largo = CGFloat.random(in: 3...11)
            let angulo = CGFloat.random(in: 0...(2 * .pi))
            let curva = CGFloat.random(in: -3...3)

            if let color = claro(CGFloat.random(in: 0.10...0.26)) {
                let fin = CGPoint(
                    x: x + cos(angulo) * largo,
                    y: y + sin(angulo) * largo
                )
                let control = CGPoint(
                    x: (x + fin.x) / 2 - sin(angulo) * curva,
                    y: (y + fin.y) / 2 + cos(angulo) * curva
                )

                contexto.setStrokeColor(color)
                contexto.setLineWidth(CGFloat.random(in: 0.5...1.2))
                contexto.beginPath()
                contexto.move(to: CGPoint(x: x, y: y))
                contexto.addQuadCurve(to: fin, control: control)
                contexto.strokePath()
            }
        }

        // 4c. Motas oscuras: polvo que tapa un poquito la luz.
        for _ in 0..<17 {
            let x = CGFloat.random(in: 0..<ancho)
            let y = CGFloat.random(in: 0..<alto)
            let largo = CGFloat.random(in: 1.5...5)
            let angulo = CGFloat.random(in: 0...(2 * .pi))

            if let color = oscuro(CGFloat.random(in: 0.04...0.12)) {
                contexto.setStrokeColor(color)
                contexto.setLineWidth(CGFloat.random(in: 0.5...1.1))
                contexto.beginPath()
                contexto.move(to: CGPoint(x: x, y: y))
                contexto.addLine(to: CGPoint(
                    x: x + cos(angulo) * largo,
                    y: y + sin(angulo) * largo
                ))
                contexto.strokePath()
            }
        }

        // 4d. Hebras largas y finitas, como pelos de tela.
        for _ in 0..<10 {
            let x = CGFloat.random(in: 0..<ancho)
            let y = CGFloat.random(in: 0..<alto)
            let angulo = CGFloat.random(in: 0...(2 * .pi))
            let largo = CGFloat.random(in: 14...46)
            let curva = CGFloat.random(in: -6...6)

            if let color = claro(CGFloat.random(in: 0.06...0.15)) {
                let fin = CGPoint(
                    x: x + cos(angulo) * largo,
                    y: y + sin(angulo) * largo
                )
                let control = CGPoint(
                    x: (x + fin.x) / 2 - sin(angulo) * curva,
                    y: (y + fin.y) / 2 + cos(angulo) * curva
                )

                contexto.setStrokeColor(color)
                contexto.setLineWidth(CGFloat.random(in: 0.4...0.8))
                contexto.beginPath()
                contexto.move(to: CGPoint(x: x, y: y))
                contexto.addQuadCurve(to: fin, control: control)
                contexto.strokePath()
            }
        }

        guard let cg = contexto.makeImage() else { return nil }

        var imagen = CIImage(cgImage: cg)

        // Un desenfoque chiquito para que no parezcan lineas de paint.
        let suave = CIFilter.gaussianBlur()
        suave.inputImage = imagen
        suave.radius = 0.5
        if let salida = suave.outputImage?.cropped(to: imagen.extent) {
            imagen = salida
        }

        return imagen
    }()

    private static func rayones(
        _ imagen: CIImage,
        cantidad: CGFloat,
        desfase: CGPoint = .zero,
        espejo: Bool = false
    ) -> CIImage? {
        guard let azulejo = rayonesTile, cantidad > 0.001 else { return nil }

        let repetir = CIFilter.affineTile()
        repetir.inputImage = azulejo

        // Mover el azulejo cambia cuales hebras caen en la foto.
        var transformacion = CGAffineTransform(
            translationX: desfase.x,
            y: desfase.y
        )
        if espejo {
            transformacion = transformacion.concatenating(
                CGAffineTransform(scaleX: -1, y: 1)
            )
        }
        repetir.transform = transformacion
        guard let infinito = repetir.outputImage else { return nil }

        // El negativo tiene hebras claras y oscuras. Las claras suman luz y
        // las oscuras la quitan, asi que va encima con transparencia en vez
        // de en modo screen: si no, las oscuras desaparecen.
        let escala = min(max(cantidad, 0), 1)
        let control = CIFilter.colorMatrix()
        control.inputImage = infinito.cropped(to: imagen.extent)
        control.rVector = CIVector(x: escala, y: 0, z: 0, w: 0)
        control.gVector = CIVector(x: 0, y: escala, z: 0, w: 0)
        control.bVector = CIVector(x: 0, y: 0, z: escala, w: 0)
        control.aVector = CIVector(x: 0, y: 0, z: 0, w: escala)
        guard let capa = control.outputImage else { return nil }

        let mezcla = CIFilter.sourceOverCompositing()
        mezcla.inputImage = capa
        mezcla.backgroundImage = imagen
        return mezcla.outputImage
    }

    // MARK: - Utilidades

    /// Recorta al centro con la relacion ancho/alto pedida (ej. 9/16 para 16:9 vertical).
    static func recortar(_ imagen: UIImage, relacion: CGFloat) -> UIImage {
        let normal = normalizar(imagen)
        guard let cg = normal.cgImage, relacion > 0 else { return normal }

        let ancho = CGFloat(cg.width)
        let alto = CGFloat(cg.height)
        guard ancho > 0, alto > 0 else { return normal }

        let actual = ancho / alto
        var recorte: CGRect

        if actual > relacion {
            let nuevoAncho = alto * relacion
            recorte = CGRect(x: (ancho - nuevoAncho) / 2, y: 0, width: nuevoAncho, height: alto)
        } else if actual < relacion {
            let nuevoAlto = ancho / relacion
            recorte = CGRect(x: 0, y: (alto - nuevoAlto) / 2, width: ancho, height: nuevoAlto)
        } else {
            return normal
        }

        guard let recortada = cg.cropping(to: recorte) else { return normal }
        return UIImage(cgImage: recortada, scale: normal.scale, orientation: .up)
    }

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
