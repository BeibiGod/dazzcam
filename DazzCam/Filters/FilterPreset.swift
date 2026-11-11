import Foundation

/// Grupos del selector de camaras.
enum FilterCategoria: String, CaseIterable, Identifiable {
    case clasica
    case vintage
    case underground

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .clasica: return "Clasicas"
        case .vintage: return "Vintage"
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
    case polaroid
    case lomo
    case crossProcess
    case bleachBypass
    case faded90s
    case copper
    case vhs
    case d3d
    case tealNight
    case warmFlash
    case noir
    case vaporwave

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .original: return "Original"
        case .portra: return "Portra 400"
        case .superia: return "Superia"
        case .kodachrome: return "Kodachrome"
        case .instColor: return "Inst Color"
        case .dazzClassic: return "Dazz Classic"
        case .cinestill: return "CineStill 800"
        case .hp5: return "HP5 B y N"
        case .polaroid: return "Polaroid 600"
        case .lomo: return "Lomo"
        case .crossProcess: return "Cross Process"
        case .bleachBypass: return "Bleach Bypass"
        case .faded90s: return "Faded 90s"
        case .copper: return "Copper"
        case .vhs: return "VHS 1987"
        case .d3d: return "D3D"
        case .tealNight: return "Teal Night"
        case .warmFlash: return "Flash Calido"
        case .noir: return "Noir"
        case .vaporwave: return "Vaporwave"
        }
    }

    var categoria: FilterCategoria {
        switch self {
        case .original, .portra, .superia, .kodachrome, .instColor, .dazzClassic:
            return .clasica
        case .cinestill, .hp5, .polaroid, .lomo, .crossProcess, .bleachBypass, .faded90s, .copper:
            return .vintage
        case .vhs, .d3d, .tealNight, .warmFlash, .noir, .vaporwave:
            return .underground
        }
    }
}
