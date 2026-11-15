import CoreImage
import Foundation
import UIKit

/// Tipografia de la fecha quemada. Son los sellos que se ven en las camaras
/// de rollo y en las apps tipo DazzCam.
enum EstiloFecha: String, CaseIterable, Identifiable {
    case dazz
    case digital
    case maquina
    case clasico
    case futura
    case mano

    // ---- agregadas en la v1.17: sellos de color ----
    case neon
    case ambar
    case plata
    case rosa

    // ---- agregadas en la v1.19: sellos retro de los 90 y los 2000 ----
    case dosMil
    case noventa

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .dazz: return "Dazz"
        case .digital: return "Digital"
        case .maquina: return "Maquina"
        case .clasico: return "Clasico"
        case .futura: return "Futura"
        case .mano: return "A mano"
        case .neon: return "Neon"
        case .ambar: return "Ambar"
        case .plata: return "Plata"
        case .rosa: return "Rosa"
        case .dosMil: return "2000s"
        case .noventa: return "90s"
        }
    }

    /// Fuente del sistema mas parecida a cada sello. Los sellos digitales usan
    /// Silkscreen (la pixelada que va dentro de la app). Si no carga, cae en la
    /// monoespaciada para no romper nada.
    func fuente(_ tamano: CGFloat) -> UIFont {
        let nombre: String

        switch self {
        case .dazz, .digital, .neon, .dosMil:
            nombre = "Silkscreen-Bold"
        case .futura, .plata, .noventa:
            nombre = "Silkscreen-Regular"
        case .maquina:
            nombre = "Courier-Bold"
        case .clasico:
            nombre = "Georgia-Bold"
        case .mano:
            nombre = "Noteworthy-Bold"
        case .ambar:
            nombre = "AmericanTypewriter-Bold"
        case .rosa:
            nombre = "Copperplate-Bold"
        }

        if let fuente = UIFont(name: nombre, size: tamano) {
            return fuente
        }
        if let pixel = UIFont(name: "Silkscreen-Regular", size: tamano) {
            return pixel
        }
        return UIFont.monospacedSystemFont(ofSize: tamano, weight: .bold)
    }

    var color: UIColor {
        switch self {
        case .dazz:
            return UIColor(red: 1.0, green: 0.58, blue: 0.16, alpha: 0.96)
        case .digital:
            return UIColor(red: 1.0, green: 0.34, blue: 0.10, alpha: 0.97)
        case .maquina:
            return UIColor(red: 1.0, green: 0.90, blue: 0.68, alpha: 0.94)
        case .clasico:
            return UIColor(red: 1.0, green: 0.78, blue: 0.42, alpha: 0.95)
        case .futura:
            return UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 0.92)
        case .mano:
            return UIColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 0.95)
        case .neon:
            return UIColor(red: 0.40, green: 1.0, blue: 0.74, alpha: 0.96)
        case .ambar:
            return UIColor(red: 1.0, green: 0.71, blue: 0.20, alpha: 0.96)
        case .plata:
            return UIColor(red: 0.90, green: 0.93, blue: 0.99, alpha: 0.93)
        case .rosa:
            return UIColor(red: 1.0, green: 0.47, blue: 0.72, alpha: 0.95)
        case .dosMil:
            return UIColor(red: 1.0, green: 0.80, blue: 0.25, alpha: 0.97)
        case .noventa:
            return UIColor(red: 0.62, green: 0.98, blue: 0.92, alpha: 0.95)
        }
    }

    /// Que tan separadas van las letras, en proporcion al tamano.
    var interletra: CGFloat {
        switch self {
        case .dazz: return 0.05
        case .digital: return 0.10
        case .maquina: return 0.03
        case .clasico: return 0.02
        case .futura: return 0.20
        case .mano: return 0
        case .neon: return 0.08
        case .ambar: return 0.02
        case .plata: return 0.12
        case .rosa: return 0.06
        case .dosMil: return 0.04
        case .noventa: return 0.14
        }
    }

    /// Dazz, Neon y 90s llevan el brillito extra alrededor del texto.
    var conBrillo: Bool { self == .dazz || self == .neon || self == .noventa }
}

/// Marca de fecha y hora, como las camaras viejitas.
enum SelloFecha: String, CaseIterable, Identifiable {
    case apagado
    case dazz
    case dazzHora
    case anio
    case fecha
    case fechaHora

    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .apagado: return "OFF"
        case .dazz: return "DAZZ"
        case .dazzHora: return "DAZZ+H"
        case .anio: return "2000"
        case .fecha: return "FECHA"
        case .fechaHora: return "F+HORA"
        }
    }

    /// Texto que se ve en el menu de la camara.
    var tituloMenu: String {
        switch self {
        case .apagado: return "Sin fecha"
        case .dazz: return "'26 11 12"
        case .dazzHora: return "'26 11 12 02:28"
        case .anio: return "2026 11 12"
        case .fecha: return "12/11/2026"
        case .fechaHora: return "12/11/2026 2:28 AM"
        }
    }

    var siguiente: SelloFecha {
        switch self {
        case .apagado: return .dazz
        case .dazz: return .dazzHora
        case .dazzHora: return .anio
        case .anio: return .fecha
        case .fecha: return .fechaHora
        case .fechaHora: return .apagado
        }
    }

    var encendido: Bool { self != .apagado }

    /// La hora siempre es la del iPhone, solo cambia como se escribe.
    /// Dazz:   '26 11 12   /   '26 11 12 02:28
    /// iPhone: 12/11/2026  /   12/11/2026 2:28 AM
    static func texto(_ modo: SelloFecha, fecha: Date = Date()) -> String {
        switch modo {
        case .apagado:
            return ""

        case .dazz:
            return formatear(fecha, patron: "''yy MM dd")

        case .dazzHora:
            return formatear(fecha, patron: "''yy MM dd HH:mm")

        case .anio:
            return formatear(fecha, patron: "yyyy MM dd")

        case .fecha:
            return formatear(fecha, patron: "dd/MM/yyyy")

        case .fechaHora:
            return formatear(fecha, patron: "dd/MM/yyyy h:mm a")
        }
    }

    private static func formatear(_ fecha: Date, patron: String) -> String {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.timeZone = TimeZone.current
        formato.dateFormat = patron
        return formato.string(from: fecha)
    }

    /// Quema la fecha en la foto, abajo a la derecha.
    static func estampar(
        _ imagen: UIImage,
        modo: SelloFecha,
        estilo: EstiloFecha = .dazz
    ) -> UIImage {
        guard modo.encendido else { return imagen }

        let base = FilterEngine.normalizar(imagen)
        let texto = texto(modo)
        guard !texto.isEmpty else { return base }

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = base.scale
        formato.opaque = true
        let renderer = UIGraphicsImageRenderer(size: base.size, format: formato)

        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: base.size))

            let ancho = base.size.width
            let alto = base.size.height
            let esDazz = estilo.conBrillo
            let tamano = max(ancho * (esDazz ? 0.036 : 0.042), 10)
            let letras = piezas(texto, tamanoFuente: tamano, estilo: estilo)

            let medida = letras.principal.size()
            let margen = ancho * 0.032
            let punto = CGPoint(
                x: ancho - medida.width - margen,
                y: alto - medida.height - margen
            )
            let corrimiento = max(tamano * 0.05, 1)

            letras.sombra.draw(at: CGPoint(x: punto.x + corrimiento, y: punto.y + corrimiento))
            if esDazz {
                letras.brillo.draw(at: CGPoint(x: punto.x - 0.6, y: punto.y - 0.6))
                letras.brillo.draw(at: CGPoint(x: punto.x + 0.6, y: punto.y + 0.6))
            }
            letras.principal.draw(at: punto)
        }
    }

    /// Capa chiquita con la fecha dibujada, para pegarla en cada cuadro del
    /// video sin tener que dibujar la foto entera. Devuelve nil si esta apagada.
    static func capaVideo(
        _ modo: SelloFecha,
        fecha: Date,
        tamano: CGSize,
        estilo: EstiloFecha = .dazz
    ) -> CIImage? {
        guard modo.encendido, tamano.width > 1, tamano.height > 1 else { return nil }

        let texto = texto(modo, fecha: fecha)
        guard !texto.isEmpty else { return nil }

        let esDazz = estilo.conBrillo
        let tamanoFuente = max(tamano.width * (esDazz ? 0.036 : 0.042), 10)
        let letras = piezas(texto, tamanoFuente: tamanoFuente, estilo: estilo)

        let medida = letras.principal.size()
        let relleno = max(tamanoFuente * 0.22, 2)
        let lienzo = CGSize(
            width: ceil(medida.width + relleno * 2),
            height: ceil(medida.height + relleno * 2)
        )

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = false

        let imagen = UIGraphicsImageRenderer(size: lienzo, format: formato).image { _ in
            let punto = CGPoint(x: relleno, y: relleno)
            let corrimiento = max(tamanoFuente * 0.05, 1)

            letras.sombra.draw(at: CGPoint(x: punto.x + corrimiento, y: punto.y + corrimiento))
            if esDazz {
                letras.brillo.draw(at: CGPoint(x: punto.x - 0.6, y: punto.y - 0.6))
                letras.brillo.draw(at: CGPoint(x: punto.x + 0.6, y: punto.y + 0.6))
            }
            letras.principal.draw(at: punto)
        }

        guard let cg = imagen.cgImage else { return nil }
        return CIImage(cgImage: cg)
    }

    /// El mismo estilo para fotos y video: color y fuente segun el sello,
    /// con sombra suave y, en Dazz, un brillito alrededor.
    private static func piezas(
        _ texto: String,
        tamanoFuente: CGFloat,
        estilo: EstiloFecha
    ) -> (principal: NSAttributedString, brillo: NSAttributedString, sombra: NSAttributedString) {
        let fuente = estilo.fuente(tamanoFuente)
        let interletra = estilo.interletra * tamanoFuente

        let principal = NSAttributedString(
            string: texto,
            attributes: [
                .font: fuente,
                .kern: interletra,
                .foregroundColor: estilo.color
            ]
        )
        let brillo = NSAttributedString(
            string: texto,
            attributes: [
                .font: fuente,
                .kern: interletra,
                .foregroundColor: estilo.color.withAlphaComponent(0.45)
            ]
        )
        let sombra = NSAttributedString(
            string: texto,
            attributes: [
                .font: fuente,
                .kern: interletra,
                .foregroundColor: UIColor.black.withAlphaComponent(0.5)
            ]
        )

        return (principal, brillo, sombra)
    }
}
