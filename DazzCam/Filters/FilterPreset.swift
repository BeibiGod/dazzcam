import Foundation

/// Grupos del selector de camaras.
enum FilterCategoria: String, CaseIterable, Identifiable {
    case clasica
    case vintage
    case instantanea
    case underground

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .clasica: return "Clasicas"
        case .vintage: return "Vintage"
        case .instantanea: return "Polaroid"
        case .underground: return "Underground"
        }
    }
}

/// Tipo de camara real que imita cada look (para el dibujito del selector).
enum FamiliaCamara {
    case compacta
    case reflex
    case instantanea
    case digital
}

/// Las "camaritas": cada una es un look de pelicula completo.
enum FilterPreset: String, CaseIterable, Identifiable {
    case original
    case portra
    case superia
    case kodachrome
    case instColor
    case dazzClassic

    case cinestill
    case hp5
    case lomo
    case crossProcess
    case bleachBypass
    case faded90s
    case copper
    case kodakGold
    case ektar100
    case fujiPro400
    case delta3200
    case agfaVista

    case polaroid600
    case sx70
    case instaxMini
    case instaxWide
    case polaroidFrio
    case polaroidNoir

    case vhs
    case d3d
    case tealNight
    case warmFlash
    case noir
    case vaporwave
    case chatarraCCD

    // ---- agregadas en la v1.4 ----
    case contaxT2
    case goldenHour

    case ultramax
    case fujiC200
    case provia
    case velvia
    case triX
    case tmax
    case cinestill50d
    case ektachrome
    case disposable
    case sepiaViejo

    case polaroidGo
    case instaxMono

    case y2kDigi

    // ---- agregadas en la v1.7: Framed, ISM, OldRoll y Tezza ----
    case framedSoft
    case framedFade
    case ismPastel
    case ismCream
    case ismNight
    case oldRoll35
    case oldRollFlash
    case oldRoll8
    case oldRollInstant
    case tezzaClean
    case tezzaWarm
    case tezzaGrain
    case tezzaPolaroid
    case sakura
    case latte
    case oceanFade
    case cinemaTeal
    case disco
    case milk
    case neonDream

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .original: return "Original"
        case .portra: return "Portra 400"
        case .superia: return "Superia 400"
        case .kodachrome: return "Kodachrome 64"
        case .instColor: return "Inst Color"
        case .dazzClassic: return "Dazz Classic"

        case .cinestill: return "CineStill 800"
        case .hp5: return "HP5 B y N"
        case .lomo: return "Lomo"
        case .crossProcess: return "Cross Process"
        case .bleachBypass: return "Bleach Bypass"
        case .faded90s: return "Faded 90s"
        case .copper: return "Copper"
        case .kodakGold: return "Kodak Gold 200"
        case .ektar100: return "Ektar 100"
        case .fujiPro400: return "Fuji Pro 400H"
        case .delta3200: return "Delta 3200"
        case .agfaVista: return "Agfa Vista"

        case .polaroid600: return "Polaroid 600"
        case .sx70: return "SX-70"
        case .instaxMini: return "Instax Mini"
        case .instaxWide: return "Instax Wide"
        case .polaroidFrio: return "Polaroid Frio"
        case .polaroidNoir: return "Polaroid Noir"

        case .vhs: return "VHS 1987"
        case .d3d: return "D3D"
        case .tealNight: return "Teal Night"
        case .warmFlash: return "Flash Calido"
        case .noir: return "Noir"
        case .vaporwave: return "Vaporwave"
        case .chatarraCCD: return "Chatarra CCD"

        case .contaxT2: return "Contax T2"
        case .goldenHour: return "Golden Hour"
        case .ultramax: return "Ultramax 400"
        case .fujiC200: return "Fuji C200"
        case .provia: return "Provia 100F"
        case .velvia: return "Velvia 50"
        case .triX: return "Tri-X 400"
        case .tmax: return "T-Max 3200"
        case .cinestill50d: return "CineStill 50D"
        case .ektachrome: return "Ektachrome"
        case .disposable: return "Desechable"
        case .sepiaViejo: return "Sepia 1920"
        case .polaroidGo: return "Polaroid Go"
        case .instaxMono: return "Instax Mono"
        case .y2kDigi: return "Y2K Digi"

        case .framedSoft: return "Framed Soft"
        case .framedFade: return "Framed Fade"
        case .ismPastel: return "ISM Pastel"
        case .ismCream: return "ISM Cream"
        case .ismNight: return "ISM Night"
        case .oldRoll35: return "OldRoll 35"
        case .oldRollFlash: return "OldRoll Flash"
        case .oldRoll8: return "OldRoll 8mm"
        case .oldRollInstant: return "OldRoll Instant"
        case .tezzaClean: return "Tezza Clean"
        case .tezzaWarm: return "Tezza Warm"
        case .tezzaGrain: return "Tezza Grain"
        case .tezzaPolaroid: return "Tezza Polaroid"
        case .sakura: return "Sakura"
        case .latte: return "Latte"
        case .oceanFade: return "Ocean Fade"
        case .cinemaTeal: return "Cinema Teal"
        case .disco: return "Disco"
        case .milk: return "Milk"
        case .neonDream: return "Neon Dream"
        }
    }

    /// Marca real de la pelicula o camara.
    var marca: String {
        switch self {
        case .portra, .kodachrome, .kodakGold, .ektar100, .ultramax,
             .triX, .tmax, .ektachrome, .disposable, .goldenHour:
            return "KODAK"
        case .superia, .fujiPro400, .provia, .velvia, .fujiC200,
             .instaxMini, .instaxWide, .instaxMono:
            return "FUJIFILM"
        case .polaroid600, .sx70, .polaroidFrio, .polaroidNoir,
             .polaroidGo, .instColor:
            return "POLAROID"
        case .hp5, .delta3200:
            return "ILFORD"
        case .agfaVista:
            return "AGFA"
        case .cinestill, .cinestill50d:
            return "CINESTILL"
        case .contaxT2:
            return "CONTAX"
        case .y2kDigi, .chatarraCCD:
            return "SONY"
        case .framedSoft, .framedFade:
            return "FRAMED"
        case .ismPastel, .ismCream, .ismNight:
            return "ISM"
        case .oldRoll35, .oldRollFlash, .oldRoll8, .oldRollInstant:
            return "OLDROLL"
        case .tezzaClean, .tezzaWarm, .tezzaGrain, .tezzaPolaroid:
            return "TEZZA"
        default:
            return "BEIBI"
        }
    }

    /// Como se ve la camarita en el selector.
    var familia: FamiliaCamara {
        switch self {
        case .polaroid600, .sx70, .instaxMini, .instaxWide,
             .polaroidFrio, .polaroidNoir, .polaroidGo, .instaxMono,
             .tezzaPolaroid, .oldRollInstant:
            return .instantanea
        case .hp5, .delta3200, .triX, .tmax:
            return .reflex
        case .vhs, .d3d, .tealNight, .vaporwave, .chatarraCCD, .y2kDigi,
             .ismNight, .disco, .neonDream:
            return .digital
        default:
            return .compacta
        }
    }

    var categoria: FilterCategoria {
        switch self {
        case .original, .portra, .superia, .kodachrome, .instColor, .dazzClassic,
             .contaxT2, .goldenHour, .tezzaClean, .tezzaWarm, .framedSoft:
            return .clasica
        case .cinestill, .hp5, .lomo, .crossProcess, .bleachBypass,
             .faded90s, .copper, .kodakGold, .ektar100, .fujiPro400,
             .delta3200, .agfaVista, .ultramax, .fujiC200, .provia, .velvia,
             .triX, .tmax, .cinestill50d, .ektachrome, .disposable, .sepiaViejo,
             .ismPastel, .ismCream, .oldRoll35, .oldRollFlash, .oldRoll8,
             .tezzaGrain, .sakura, .latte, .oceanFade, .framedFade,
             .cinemaTeal, .milk:
            return .vintage
        case .polaroid600, .sx70, .instaxMini, .instaxWide, .polaroidFrio,
             .polaroidNoir, .polaroidGo, .instaxMono, .tezzaPolaroid,
             .oldRollInstant:
            return .instantanea
        case .vhs, .d3d, .tealNight, .warmFlash, .noir, .vaporwave,
             .chatarraCCD, .y2kDigi, .ismNight, .disco, .neonDream:
            return .underground
        }
    }

    /// Camaras reales, sin contar "Original".
    static var cantidadCamaras: Int {
        allCases.count - 1
    }
}
