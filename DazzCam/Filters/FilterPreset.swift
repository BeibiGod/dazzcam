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
        }
    }

    var categoria: FilterCategoria {
        switch self {
        case .original, .portra, .superia, .kodachrome, .instColor, .dazzClassic:
            return .clasica
        case .cinestill, .hp5, .lomo, .crossProcess, .bleachBypass,
             .faded90s, .copper, .kodakGold, .ektar100, .fujiPro400,
             .delta3200, .agfaVista:
            return .vintage
        case .polaroid600, .sx70, .instaxMini, .instaxWide, .polaroidFrio, .polaroidNoir:
            return .instantanea
        case .vhs, .d3d, .tealNight, .warmFlash, .noir, .vaporwave, .chatarraCCD:
            return .underground
        }
    }

    /// Camaras reales, sin contar "Original".
    static var cantidadCamaras: Int {
        allCases.count - 1
    }
}
