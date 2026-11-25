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
enum FilterPreset: String, CaseIterable, Identifiable, Codable {
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

    // ---- agregadas en la v1.15: SWAG, Jackboys y Riviera ----
    case swagLive
    case jackboys
    case riviera92

    // ---- agregadas en la v1.17: camaras de rollo ----
    case yashicaT4
    case olympusMju
    case canonSure
    case nikonFm2
    case praktica
    case zenit12
    case kodakVR
    case agfaOptima

    // ---- agregadas en la v1.24: desechables ----
    case funSaver
    case quickSnap
    case sprite35
    case leBox
    case simpleUse
    case sportDesechable

    // ---- agregadas en la v1.24: los 2000 ----
    case powerShot
    case cyberShot
    case coolpix
    case exilim
    case lumix
    case easyShare
    case handycam

    // ---- agregadas en la v1.24: vision nocturna ----
    case nightshotVideo
    case nightshotFoto

    // ---- agregadas en la v1.25.19: looks de Prequel y Tezza ----
    case g7x
    case digitalFlash
    case tezza99

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .original: return "Original"
        case .portra: return "Portra 400"
        case .superia: return "Superia 400"
        case .kodachrome: return "Kodachrome 64"
        case .instColor: return "Inst Color"
        case .dazzClassic: return "D Classic"

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

        case .swagLive: return "SWAG Live"
        case .jackboys: return "Jackboys"
        case .riviera92: return "Riviera 92"

        case .yashicaT4: return "Yashica T4"
        case .olympusMju: return "Olympus Mju"
        case .canonSure: return "Canon Sure Shot"
        case .nikonFm2: return "Nikon FM2"
        case .praktica: return "Praktica"
        case .zenit12: return "Zenit 12"
        case .kodakVR: return "Kodak VR 35"
        case .agfaOptima: return "Agfa Optima"

        case .funSaver: return "FunSaver"
        case .quickSnap: return "QuickSnap"
        case .sprite35: return "Sprite 35"
        case .leBox: return "Le Box"
        case .simpleUse: return "Simple Use"
        case .sportDesechable: return "Sport Desechable"

        case .powerShot: return "PowerShot A"
        case .cyberShot: return "Cyber-shot"
        case .coolpix: return "Coolpix"
        case .exilim: return "Exilim"
        case .lumix: return "Lumix"
        case .easyShare: return "EasyShare"
        case .handycam: return "Handycam"

        case .nightshotVideo: return "Nightshot Video"
        case .nightshotFoto: return "Nightshot Foto"

        case .g7x: return "G7X"
        case .digitalFlash: return "Digital Flash"
        case .tezza99: return "1999"
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
        case .dazzClassic:
            return "DAZZ"
        case .framedSoft, .framedFade:
            return "FRAMED"
        case .ismPastel, .ismCream, .ismNight:
            return "ISM"
        case .oldRoll35, .oldRollFlash, .oldRoll8, .oldRollInstant:
            return "OLDROLL"
        case .tezzaClean, .tezzaWarm, .tezzaGrain, .tezzaPolaroid, .tezza99:
            return "TEZZA"
        case .swagLive:
            return "SWAG"
        case .jackboys:
            return "JACKBOYS"
        case .riviera92:
            return "RIVIERA"
        case .yashicaT4:
            return "YASHICA"
        case .olympusMju:
            return "OLYMPUS"
        case .canonSure, .g7x:
            return "CANON"
        case .nikonFm2:
            return "NIKON"
        case .praktica:
            return "PRAKTICA"
        case .zenit12:
            return "ZENIT"
        case .kodakVR:
            return "KODAK"
        case .agfaOptima:
            return "AGFA"
        case .funSaver, .sportDesechable, .easyShare:
            return "KODAK"
        case .quickSnap:
            return "FUJIFILM"
        case .sprite35:
            return "ILFORD"
        case .leBox:
            return "AGFA"
        case .simpleUse:
            return "LOMO"
        case .powerShot:
            return "CANON"
        case .cyberShot, .handycam, .nightshotVideo, .nightshotFoto:
            return "SONY"
        case .coolpix:
            return "NIKON"
        case .exilim:
            return "CASIO"
        case .lumix:
            return "PANASONIC"
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
        case .hp5, .delta3200, .triX, .tmax, .nikonFm2, .praktica, .zenit12:
            return .reflex
        case .vhs, .d3d, .tealNight, .vaporwave, .chatarraCCD, .y2kDigi,
             .ismNight, .disco, .neonDream, .powerShot, .cyberShot, .coolpix,
             .exilim, .lumix, .easyShare, .handycam, .nightshotVideo,
             .nightshotFoto, .digitalFlash, .tezza99:
            return .digital
        case .funSaver, .quickSnap, .sprite35, .leBox, .simpleUse,
             .sportDesechable:
            return .compacta
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
             .cinemaTeal, .milk, .swagLive, .jackboys, .riviera92,
             .yashicaT4, .olympusMju, .canonSure, .nikonFm2,
             .praktica, .zenit12, .kodakVR, .agfaOptima,
             .funSaver, .quickSnap, .sprite35, .leBox, .simpleUse,
             .sportDesechable:
            return .vintage
        case .polaroid600, .sx70, .instaxMini, .instaxWide, .polaroidFrio,
             .polaroidNoir, .polaroidGo, .instaxMono, .tezzaPolaroid,
             .oldRollInstant:
            return .instantanea
        case .vhs, .d3d, .tealNight, .warmFlash, .noir, .vaporwave,
             .chatarraCCD, .y2kDigi, .ismNight, .disco, .neonDream,
             .powerShot, .cyberShot, .coolpix, .exilim, .lumix, .easyShare,
             .handycam, .nightshotVideo, .nightshotFoto, .g7x, .digitalFlash,
             .tezza99:
            return .underground
        }
    }

    /// Sello que traia la camara de verdad. Las que no tenian respaldo de
    /// fecha arrancan apagadas; se pueden prender a mano cuando quieras.
    var selloDeFabrica: SelloFecha {
        switch self {
        // Sin fecha: instantaneas, desechables, Lomo y reflex mecanicas.
        case .original, .polaroid600, .sx70, .instaxMini, .instaxWide,
             .polaroidFrio, .polaroidNoir, .polaroidGo, .instaxMono,
             .tezzaPolaroid, .oldRollInstant, .oldRoll35, .oldRollFlash,
             .oldRoll8, .disposable, .lomo, .nikonFm2, .praktica, .zenit12,
             .funSaver, .quickSnap, .sprite35, .leBox, .simpleUse,
             .sportDesechable:
            return .apagado

        // Digitales y videocamaras: año completo, como en los 2000.
        case .y2kDigi, .chatarraCCD, .vhs, .d3d, .disco, .vaporwave,
             .neonDream, .tealNight, .ismNight, .powerShot, .cyberShot,
             .coolpix, .exilim, .lumix, .easyShare, .handycam, .tezza99:
            return .anio

        // Vision nocturna: el sello de la videocamara, con hora y segundos.
        case .nightshotVideo, .nightshotFoto:
            return .vision

        // Las reconocidas por su respaldo de fecha de los 90.
        case .contaxT2, .yashicaT4, .olympusMju, .canonSure, .kodakVR,
             .agfaOptima:
            return .dazz

        // El resto: fecha corta, como la mayoria de las compactas.
        default:
            return .dazz
        }
    }

    /// Tipografia y color con los que esa camara quema la fecha. Van con su
    /// caracter: calidas las de rollo, frias las digitales, plata las de B y N.
    var estiloDeFecha: EstiloFecha {
        switch self {
        // ---- calidas de rollo ----
        case .kodakGold, .ultramax, .goldenHour, .contaxT2, .kodakVR,
             .dazzClassic, .sepiaViejo, .g7x, .digitalFlash:
            return .dazz

        case .portra, .warmFlash, .yashicaT4, .riviera92, .tezzaWarm,
             .faded90s:
            return .ambar

        case .olympusMju, .instColor, .framedSoft, .framedFade, .ismCream,
             .latte:
            return .maquina

        case .superia, .canonSure, .tezzaGrain:
            return .clasico

        // ---- rojas y rosas ----
        case .agfaVista, .agfaOptima, .kodachrome, .ektar100, .copper,
             .velvia:
            return .digital

        case .sakura, .ismPastel, .crossProcess, .vaporwave, .disco:
            return .rosa

        // ---- frias y digitales ----
        case .vhs, .tealNight, .cinestill, .cinestill50d, .oceanFade,
             .cinemaTeal:
            return .noventa

        case .y2kDigi, .chatarraCCD, .d3d, .jackboys, .powerShot, .cyberShot,
             .coolpix, .exilim, .lumix, .easyShare, .handycam, .tezza99:
            return .dosMil

        case .funSaver, .quickSnap, .sportDesechable:
            return .dazz

        case .sprite35, .leBox:
            return .clasico

        case .simpleUse:
            return .ambar

        case .nightshotVideo, .nightshotFoto:
            return .vision

        case .neonDream, .swagLive, .fujiPro400, .fujiC200, .provia:
            return .neon

        // ---- plata y blanco para B y N ----
        case .hp5, .delta3200, .triX, .tmax, .bleachBypass, .ektachrome,
             .tezzaClean:
            return .plata

        case .noir, .milk:
            return .futura

        // ---- apagadas: el estilo queda listo por si la prendes ----
        case .original, .polaroid600, .sx70, .instaxMini, .instaxWide,
             .polaroidFrio, .polaroidNoir, .polaroidGo, .instaxMono,
             .tezzaPolaroid, .oldRollInstant, .oldRoll35, .oldRollFlash,
             .oldRoll8, .disposable, .lomo, .nikonFm2, .praktica, .zenit12,
             .ismNight:
            return .plata
        }
    }

    /// Camaras reales, sin contar "Original".
    static var cantidadCamaras: Int {
        allCases.count - 1
    }

    /// Año de la camara o del rollo que imita. Sirve para ordenar el selector.
    var anio: Int {
        switch self {
        case .original: return 2026

        // ---- rollo clasico ----
        case .portra: return 1998
        case .superia: return 1998
        case .kodachrome: return 1974
        case .instColor: return 2024
        case .dazzClassic: return 2024
        case .cinestill: return 2017
        case .hp5: return 1976
        case .lomo: return 1992
        case .crossProcess: return 1995
        case .bleachBypass: return 1999
        case .faded90s: return 1993
        case .copper: return 2023
        case .kodakGold: return 1986
        case .ektar100: return 1989
        case .fujiPro400: return 2004
        case .delta3200: return 1995
        case .agfaVista: return 1996
        case .contaxT2: return 1990
        case .goldenHour: return 2021
        case .ultramax: return 1997
        case .fujiC200: return 2001
        case .provia: return 1994
        case .velvia: return 1990
        case .triX: return 1954
        case .tmax: return 1986
        case .cinestill50d: return 2018
        case .ektachrome: return 1962
        case .disposable: return 1988
        case .sepiaViejo: return 1920

        // ---- instantaneas ----
        case .polaroid600: return 1981
        case .sx70: return 1972
        case .instaxMini: return 1998
        case .instaxWide: return 1999
        case .polaroidFrio: return 1985
        case .polaroidNoir: return 1982
        case .polaroidGo: return 2021
        case .instaxMono: return 2016

        // ---- video y digitales ----
        case .vhs: return 1987
        case .d3d: return 2003
        case .tealNight: return 2004
        case .warmFlash: return 1998
        case .noir: return 1995
        case .vaporwave: return 2019
        case .chatarraCCD: return 2002
        case .y2kDigi: return 2000

        // ---- apps ----
        case .framedSoft, .framedFade: return 2023
        case .ismPastel, .ismCream, .ismNight: return 2022
        case .oldRoll35, .oldRollFlash, .oldRoll8, .oldRollInstant: return 2021
        case .tezzaClean, .tezzaWarm, .tezzaGrain, .tezzaPolaroid: return 2019
        case .sakura, .latte, .oceanFade: return 2020
        case .cinemaTeal: return 2018
        case .disco: return 1978
        case .milk: return 2021
        case .neonDream: return 2020
        case .swagLive: return 2022
        case .jackboys: return 2019
        case .riviera92: return 1992

        // ---- compactas y reflex de rollo ----
        case .yashicaT4: return 1988
        case .olympusMju: return 1991
        case .canonSure: return 1985
        case .nikonFm2: return 1982
        case .praktica: return 1975
        case .zenit12: return 1973
        case .kodakVR: return 1990
        case .agfaOptima: return 1979

        // ---- desechables ----
        case .funSaver: return 1987
        case .quickSnap: return 1986
        case .sprite35: return 1965
        case .leBox: return 1992
        case .simpleUse: return 2017
        case .sportDesechable: return 1989

        // ---- los 2000 ----
        case .powerShot: return 2001
        case .cyberShot: return 2001
        case .coolpix: return 1997
        case .exilim: return 2002
        case .lumix: return 2001
        case .easyShare: return 2001
        case .handycam: return 2000

        // ---- vision nocturna ----
        case .nightshotVideo: return 1998
        case .nightshotFoto: return 1998

        // ---- looks de Prequel y Tezza ----
        case .g7x: return 2014
        case .digitalFlash: return 1998
        case .tezza99: return 1999
        }
    }

    /// Texto que la camara traia quemado en pantalla, ademas de la fecha.
    /// Solo la vision nocturna lo lleva.
    var rotulo: String? {
        switch self {
        case .nightshotVideo, .nightshotFoto:
            return "NIGHTSHOT"
        default:
            return nil
        }
    }

    /// true si es una videocamara. El resto son camaras de foto.
    var esVideo: Bool {
        switch self {
        case .vhs, .d3d, .handycam, .nightshotVideo, .tezza99:
            return true
        default:
            return false
        }
    }

    /// Un grupo del selector: fotos o video, ordenadas por año.
    struct GrupoTipo: Identifiable {
        let id: String
        let titulo: String
        let camaras: [FilterPreset]
    }

    /// Pone las favoritas adelante sin cambiar el orden del resto.
    static func ordenadas(
        _ lista: [FilterPreset],
        favoritas: Set<FilterPreset>
    ) -> [FilterPreset] {
        let primeras = lista.filter { favoritas.contains($0) }
        let resto = lista.filter { !favoritas.contains($0) }
        return primeras + resto
    }

    /// Camaras separadas en foto y video, de la mas vieja a la mas reciente.
    static var porTipo: [GrupoTipo] {        let resto = allCases.filter { $0 != .original }
        let fotos = resto.filter { !$0.esVideo }.sorted { a, b in
            a.anio == b.anio ? a.nombre < b.nombre : a.anio < b.anio
        }
        let videos = resto.filter { $0.esVideo }.sorted { a, b in
            a.anio == b.anio ? a.nombre < b.nombre : a.anio < b.anio
        }

        return [
            GrupoTipo(id: "fotos", titulo: "CAMARAS DE FOTO", camaras: fotos),
            GrupoTipo(id: "video", titulo: "CAMARAS DE VIDEO", camaras: videos)
        ].filter { !$0.camaras.isEmpty }
    }
}
