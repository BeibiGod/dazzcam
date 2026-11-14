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
    var fuga: CGFloat = 0                // luz que se cuela por la esquina
    var fugaEsquina: Int = 0             // 0-3: cual esquina usa la fuga
    var blancoYNegro: Bool = false
}

/// Lo que el usuario puede mover con los dedos. nil = lo que trae la camara.
struct ControlesLook: Equatable {
    var intensidad: CGFloat = 1
    var rayones: CGFloat? = nil
    var fuga: CGFloat? = nil
    var grano: CGFloat? = nil

    /// true si el usuario no ha tocado nada.
    var automatico: Bool {
        abs(intensidad - 1) < 0.001 && rayones == nil && fuga == nil && grano == nil
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
        momento: UInt64 = 0
    ) -> UIImage {
        guard preset != .original else { return imagen }

        let base = normalizar(imagen)
        guard let entrada = CIImage(image: base) else { return imagen }
        guard let salida = cadena(
            preset,
            entrada: entrada,
            controles: controles,
            semilla: semilla,
            momento: momento
        ) else { return imagen }

        guard let cg = contexto.createCGImage(salida, from: salida.extent) else {
            return imagen
        }
        return UIImage(cgImage: cg, scale: base.scale, orientation: .up)
    }

    /// `momento` es el numero de cuadro. En foto vale 0 y el patron queda
    /// quieto; en video cambia cuadro a cuadro para que los rayones se muevan
    /// como en un negativo de verdad.
    static func cadena(
        _ preset: FilterPreset,
        entrada: CIImage,
        controles: ControlesLook = ControlesLook(),
        semilla: UInt64 = 0,
        momento: UInt64 = 0
    ) -> CIImage? {
        guard preset != .original else { return entrada }

        var a = ajuste(preset)
        a.rayones = controles.rayones ?? a.rayones
        a.fuga = controles.fuga ?? a.fuga
        a.grano = controles.grano ?? a.grano

        guard let filtrada = aplicar(
            a,
            a: entrada,
            semilla: semilla,
            momento: momento
        ) else { return nil }
        guard controles.intensidad < 0.999 else { return filtrada }

        return mezclar(filtrada, con: entrada, cantidad: controles.intensidad)
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
            a.temperatura = 7100; a.saturacion = 1.04; a.contraste = 0.99
            a.desvanecido = 0.025; a.grano = 0.04; a.vineta = 0.2

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
            a.temperatura = 8300; a.saturacion = 1.15; a.contraste = 1.02
            a.desvanecido = 0.02; a.grano = 0.05; a.vineta = 0.22

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
        case .chatarraCCD:
            a.fuga = 0.35
        case .framedFade:
            a.fuga = 0.35
        case .vhs, .oldRoll35:
            a.fuga = 0.3
        case .y2kDigi, .d3d, .tezzaPolaroid, .goldenHour:
            a.fuga = 0.25
        case .polaroid600, .sx70, .instColor:
            a.fuga = 0.2
        default:
            a.fuga = 0
        }

        // Cada camara tiene su esquina de fuga (siempre la misma).
        a.fugaEsquina = preset.rawValue.unicodeScalars.reduce(0) {
            $0 + Int($1.value)
        } % 4

        return a
    }

    // MARK: - Cadena generica

    private static func aplicar(
        _ a: AjusteFoto,
        a imagen: CIImage,
        semilla: UInt64,
        momento: UInt64
    ) -> CIImage? {
        var actual = imagen
        var azar = Azar(semilla)

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

        // 7. rayones finos de pelicula: cada toma tiene su patron y en video
        //    se mueven un poco cuadro a cuadro, como en un negativo real.
        if a.rayones > 0 {
            let fuerzaBase = min(max(a.rayones * azar.valor(0.75...1.2), 0), 1)
            let desfaseBase = CGPoint(
                x: azar.valor(0...2048),
                y: azar.valor(0...2048)
            )
            let espejo = azar.entero(2) == 1

            // Movimiento suave mas un temblor chiquito, para que no parezca
            // un patron pegado encima de la imagen.
            let fase = Double(momento % 2400) / 24.0
            var temblor = Azar(semilla &+ (momento &* 0x9E37_79B9_7F4A_7C15))
            let deriva = CGPoint(
                x: CGFloat(sin(fase * 1.7)) * 9
                    + CGFloat(cos(fase * 4.3)) * 3
                    + temblor.valor(-1.5...1.5),
                y: CGFloat(cos(fase * 1.1)) * 4
                    + temblor.valor(-1...1)
            )
            let parpadeo = 0.9
                + CGFloat(sin(fase * 6.5)) * 0.07
                + temblor.valor(0...0.06)
            let fuerza = min(max(fuerzaBase * parpadeo, 0), 1)

            if let conRayones = rayones(
                actual,
                cantidad: fuerza,
                desfase: CGPoint(
                    x: desfaseBase.x + deriva.x,
                    y: desfaseBase.y + deriva.y
                ),
                espejo: espejo
            ) {
                actual = conRayones
            }
        }

        // 8. fuga de luz: cada foto elige su esquina y su fuerza
        if a.fuga > 0 {
            let esquina = (a.fugaEsquina + azar.entero(4)) % 4
            let fuerza = min(max(a.fuga * azar.valor(0.8...1.15), 0), 1)
            let radio = azar.valor(0.62...0.92)
            let corrimiento = CGPoint(
                x: azar.valor(-0.05...0.05),
                y: azar.valor(-0.05...0.05)
            )

            if let conFuga = fuga(
                actual,
                cantidad: fuerza,
                esquina: esquina,
                radio: radio,
                corrimiento: corrimiento
            ) {
                actual = conFuga
            }
        }

        return actual
    }

    // MARK: - Fuga de luz

    private static func fuga(
        _ imagen: CIImage,
        cantidad: CGFloat,
        esquina: Int,
        radio: CGFloat = 0.75,
        corrimiento: CGPoint = .zero
    ) -> CIImage? {
        let extent = imagen.extent
        let ancho = extent.width
        let alto = extent.height
        guard ancho > 0, alto > 0 else { return nil }

        let posiciones: [CGPoint] = [
            CGPoint(x: extent.minX, y: extent.maxY),
            CGPoint(x: extent.maxX, y: extent.maxY),
            CGPoint(x: extent.minX, y: extent.minY),
            CGPoint(x: extent.maxX, y: extent.minY)
        ]
        let base = posiciones[abs(esquina) % posiciones.count]
        let centro = CGPoint(
            x: base.x + corrimiento.x * ancho,
            y: base.y + corrimiento.y * alto
        )

        let gradiente = CIFilter.radialGradient()
        gradiente.center = centro
        gradiente.radius0 = 0
        gradiente.radius1 = Float(max(ancho, alto) * radio)
        gradiente.color0 = CIColor(red: 1.0, green: 0.62, blue: 0.24, alpha: 1.0)
        gradiente.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 1.0)

        guard let crudo = gradiente.outputImage?.cropped(to: extent) else { return nil }

        let control = CIFilter.colorMatrix()
        control.inputImage = crudo
        control.rVector = CIVector(x: cantidad, y: 0, z: 0, w: 0)
        control.gVector = CIVector(x: 0, y: cantidad, z: 0, w: 0)
        control.bVector = CIVector(x: 0, y: 0, z: cantidad, w: 0)
        control.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let capa = control.outputImage else { return nil }

        let mezcla = CIFilter.screenBlendMode()
        mezcla.inputImage = capa
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

    /// Rayones de una foto revelada de verdad: lineas verticales muy finas
    /// que se cortan solas, pelusas y polvo alargado. Nada de rayas largas
    /// parejas ni puntitos redondos: eso se nota hecho a computadora.
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

        let ancho = CGFloat(lado)
        let alto = CGFloat(lado)

        func tinta(_ alfa: CGFloat) -> CGColor? {
            CGColor(
                colorSpace: espacio,
                components: [1, 0.985, 0.96, alfa]
            )
        }

        // 1. Rayones de arrastre: verticales, finos y cortados en tramos.
        //    Cada tramo cambia de fuerza, como cuando el negativo se raya.
        for _ in 0..<7 {
            let x = CGFloat.random(in: 0..<ancho)
            let yInicio = CGFloat.random(in: 0..<alto)
            let largo = CGFloat.random(in: 180...900)
            var y = yInicio
            var xActual = x

            while y < yInicio + largo {
                let tramo = CGFloat.random(in: 8...46)
                let alfa = CGFloat.random(in: 0.06...0.26)
                let grosor = CGFloat.random(in: 0.55...1.5)

                if CGFloat.random(in: 0...1) > 0.22, let color = tinta(alfa) {
                    contexto.setStrokeColor(color)
                    contexto.setLineWidth(grosor)

                    let fin = min(y + tramo, yInicio + largo)
                    let desvio = CGFloat.random(in: -1.4...1.4)

                    contexto.move(to: CGPoint(x: xActual, y: y))
                    contexto.addLine(to: CGPoint(x: xActual + desvio, y: fin))
                    contexto.strokePath()

                    xActual += CGFloat.random(in: -0.35...0.35)
                }

                y += tramo + CGFloat.random(in: 2...18)
            }
        }

        // 2. Rayitas cortas de emulsion, agrupadas, casi verticales.
        for _ in 0..<4 {
            let centroX = CGFloat.random(in: 0..<ancho)
            let centroY = CGFloat.random(in: 0..<alto)

            for _ in 0..<Int.random(in: 10...24) {
                let x = centroX + CGFloat.random(in: -14...14)
                let y = centroY + CGFloat.random(in: -30...30)
                let altoRaya = CGFloat.random(in: 4...22)
                let alfa = CGFloat.random(in: 0.06...0.20)

                if let color = tinta(alfa) {
                    contexto.setStrokeColor(color)
                    contexto.setLineWidth(CGFloat.random(in: 0.45...1.0))
                    contexto.move(to: CGPoint(x: x, y: y))
                    contexto.addLine(to: CGPoint(
                        x: x + CGFloat.random(in: -1.2...1.2),
                        y: y + altoRaya
                    ))
                    contexto.strokePath()
                }
            }
        }

        // 3. Pelusas: pocas, torcidas y suaves.
        for _ in 0..<5 {
            let inicio = CGPoint(
                x: CGFloat.random(in: 0..<ancho),
                y: CGFloat.random(in: 0..<alto)
            )
            let largo = CGFloat.random(in: 26...110)
            let angulo = CGFloat.random(in: 0...(2 * .pi))
            let fin = CGPoint(
                x: inicio.x + cos(angulo) * largo,
                y: inicio.y + sin(angulo) * largo
            )
            let control = CGPoint(
                x: (inicio.x + fin.x) / 2 + CGFloat.random(in: -12...12),
                y: (inicio.y + fin.y) / 2 + CGFloat.random(in: -12...12)
            )

            if let color = tinta(CGFloat.random(in: 0.04...0.11)) {
                contexto.setStrokeColor(color)
                contexto.setLineWidth(CGFloat.random(in: 0.4...0.8))
                contexto.move(to: inicio)
                contexto.addQuadCurve(to: fin, control: control)
                contexto.strokePath()
            }
        }

        // 4. Polvo: motas alargadas, nunca circulos perfectos.
        for _ in 0..<36 {
            let x = CGFloat.random(in: 0..<ancho)
            let y = CGFloat.random(in: 0..<alto)
            let largo = CGFloat.random(in: 1.2...5.5)
            let angulo = CGFloat.random(in: 0...(2 * .pi))
            let grosor = CGFloat.random(in: 0.4...1.1)

            if let color = tinta(CGFloat.random(in: 0.08...0.30)) {
                contexto.setStrokeColor(color)
                contexto.setLineWidth(grosor)
                contexto.move(to: CGPoint(x: x, y: y))
                contexto.addLine(to: CGPoint(
                    x: x + cos(angulo) * largo,
                    y: y + sin(angulo) * largo
                ))
                contexto.strokePath()
            }
        }

        // 5. Un par de velos anchos y muy suaves, como cuando el negativo
        //    roza la guia de la camara.
        for _ in 0..<2 {
            let x = CGFloat.random(in: 0..<ancho)

            if let color = tinta(CGFloat.random(in: 0.02...0.05)) {
                contexto.setStrokeColor(color)
                contexto.setLineWidth(CGFloat.random(in: 3...9))
                contexto.move(to: CGPoint(x: x, y: 0))
                contexto.addLine(to: CGPoint(
                    x: x + CGFloat.random(in: -6...6),
                    y: alto
                ))
                contexto.strokePath()
            }
        }

        guard let cg = contexto.makeImage() else { return nil }

        var imagen = CIImage(cgImage: cg)

        // Un desenfoque chiquito para que no parezcan lineas de paint.
        let suave = CIFilter.gaussianBlur()
        suave.inputImage = imagen
        suave.radius = 0.4
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

        // Mover el azulejo cambia cuales rayones caen en la foto.
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

        let control = CIFilter.colorMatrix()
        control.inputImage = infinito.cropped(to: imagen.extent)
        control.aVector = CIVector(x: 0, y: 0, z: 0, w: min(cantidad, 0.9))
        guard let capa = control.outputImage else { return nil }

        // Screen: el rayon de un negativo se ve clarito, no negro.
        let mezcla = CIFilter.screenBlendMode()
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
