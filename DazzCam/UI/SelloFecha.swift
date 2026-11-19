import CoreImage
import Foundation
import UIKit

/// Tipografia de la fecha quemada. Son los sellos que se ven en las camaras
/// de rollo y en las apps tipo DazzCam.
enum EstiloFecha: String, CaseIterable, Identifiable, Codable {
    case dazz
    case digital
    case maquina
    case clasico
    case futura
    case mano

    // ---- sellos de color ----
    case neon
    case ambar
    case plata
    case rosa

    // ---- sellos retro de los 90 y los 2000 ----
    case dosMil
    case noventa

    // ---- vision nocturna ----
    case vision

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
        case .vision: return "Night"
        }
    }

    /// Todas pixeladas, pero cada una con su propia letra y su propio
    /// caracter. Van incluidas en la app.
    func fuente(_ tamano: CGFloat) -> UIFont {
        let nombre: String
        let escala: CGFloat

        switch self {
        case .dazz:
            nombre = "Silkscreen-Bold"
            escala = 1.0
        case .digital:
            nombre = "PressStart2P-Regular"
            escala = 0.72
        case .maquina:
            nombre = "Jersey10-Regular"
            escala = 1.04
        case .clasico:
            nombre = "Jersey10-Regular"
            escala = 1.02
        case .futura:
            nombre = "Micro5-Regular"
            escala = 1.18
        case .mano:
            nombre = "Silkscreen-Regular"
            escala = 0.96
        case .neon:
            nombre = "PressStart2P-Regular"
            escala = 0.70
        case .ambar:
            nombre = "Silkscreen-Bold"
            escala = 0.98
        case .plata:
            nombre = "Micro5-Regular"
            escala = 1.14
        case .rosa:
            nombre = "Jersey10-Regular"
            escala = 1.02
        case .dosMil:
            nombre = "PressStart2P-Regular"
            escala = 0.70
        case .noventa:
            nombre = "Micro5-Regular"
            escala = 1.16
        case .vision:
            nombre = "PressStart2P-Regular"
            escala = 0.68
        }

        let medida = max(tamano * escala, 8)

        if let fuente = UIFont(name: nombre, size: medida) {
            return fuente
        }
        if let respaldo = UIFont(name: "Silkscreen-Regular", size: tamano) {
            return respaldo
        }
        return UIFont.monospacedSystemFont(ofSize: tamano, weight: .bold)
    }

    var color: UIColor {
        switch self {
        case .dazz:
            return UIColor(red: 1.0, green: 0.60, blue: 0.18, alpha: 0.97)
        case .digital:
            return UIColor(red: 1.0, green: 0.30, blue: 0.10, alpha: 0.98)
        case .maquina:
            return UIColor(red: 1.0, green: 0.93, blue: 0.72, alpha: 0.96)
        case .clasico:
            return UIColor(red: 1.0, green: 0.80, blue: 0.46, alpha: 0.96)
        case .futura:
            return UIColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 0.94)
        case .mano:
            return UIColor(red: 1.0, green: 0.66, blue: 0.34, alpha: 0.96)
        case .neon:
            return UIColor(red: 0.36, green: 1.0, blue: 0.62, alpha: 0.98)
        case .ambar:
            return UIColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 0.97)
        case .plata:
            return UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 0.95)
        case .rosa:
            return UIColor(red: 1.0, green: 0.48, blue: 0.70, alpha: 0.96)
        case .dosMil:
            return UIColor(red: 1.0, green: 0.86, blue: 0.24, alpha: 0.98)
        case .noventa:
            return UIColor(red: 0.56, green: 1.0, blue: 0.94, alpha: 0.96)
        case .vision:
            return UIColor(red: 0.78, green: 1.0, blue: 0.78, alpha: 0.98)
        }
    }

    /// Que tan separadas van las letras, en proporcion al tamano.
    var interletra: CGFloat {
        switch self {
        case .dazz: return 0.06
        case .digital: return 0.02
        case .maquina: return 0.04
        case .clasico: return 0.03
        case .futura: return 0.18
        case .mano: return 0.02
        case .neon: return 0.02
        case .ambar: return 0.04
        case .plata: return 0.14
        case .rosa: return 0.05
        case .dosMil: return 0.02
        case .noventa: return 0.12
        case .vision: return 0.01
        }
    }

    /// Aire entre lineas cuando el sello lleva rotulo y fecha.
    var renglon: CGFloat {
        switch self {
        case .vision: return 0.22
        case .digital, .dosMil, .neon: return 0.18
        default: return 0.10
        }
    }

    /// Sellos con un brillito extra alrededor del texto.
    var conBrillo: Bool {
        switch self {
        case .dazz, .neon, .noventa, .vision:
            return true
        default:
            return false
        }
    }
}

/// Marca de fecha y hora, como las camaras viejitas.
enum SelloFecha: String, CaseIterable, Identifiable, Codable {
    case apagado
    case dazz
    case dazzHora
    case anio
    case fecha
    case fechaHora

    // ---- agregada en la v1.24: sello de vision nocturna ----
    case vision

    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .apagado: return "OFF"
        case .dazz: return "DAZZ"
        case .dazzHora: return "DAZZ+H"
        case .anio: return "2000"
        case .fecha: return "FECHA"
        case .fechaHora: return "F+HORA"
        case .vision: return "NIGHT"
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
        case .vision: return "2026 2 15 8:47 PM"
        }
    }

    var siguiente: SelloFecha {
        switch self {
        case .apagado: return .dazz
        case .dazz: return .dazzHora
        case .dazzHora: return .anio
        case .anio: return .vision
        case .vision: return .fecha
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

        case .vision:
            // Como la videocamara: año, mes y dia arriba, hora con segundos
            // abajo, sin espacio antes de AM/PM.
            return formatear(fecha, patron: "yyyy M d\nh:mm:ssa")
        }
    }

    /// Junta el rotulo de la camara (por ejemplo NIGHTSHOT) con la fecha.
    /// El rotulo es parte del visor, asi que se queda aunque apagues la fecha.
    static func textoCompleto(
        _ modo: SelloFecha,
        fecha: Date = Date(),
        rotulo: String? = nil
    ) -> String {
        var lineas: [String] = []

        if let rotulo = rotulo, !rotulo.isEmpty {
            lineas.append(rotulo)
        }

        let cuerpo = texto(modo, fecha: fecha)
        if !cuerpo.isEmpty {
            lineas.append(cuerpo)
        }

        return lineas.joined(separator: "\n")
    }

    private static func formatear(_ fecha: Date, patron: String) -> String {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.timeZone = TimeZone.current
        formato.dateFormat = patron
        return formato.string(from: fecha)
    }

    /// Quema la fecha en la foto, abajo a la derecha. Si la camara traia un
    /// rotulo en pantalla (NIGHTSHOT), va arriba de la fecha.
    static func estampar(
        _ imagen: UIImage,
        modo: SelloFecha,
        estilo: EstiloFecha = .dazz,
        rotulo: String? = nil
    ) -> UIImage {
        let texto = textoCompleto(modo, rotulo: rotulo)
        guard !texto.isEmpty else { return imagen }

        let base = FilterEngine.normalizar(imagen)

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

            let medida = medida(letras.principal)
            let margen = ancho * 0.032
            let centrado = (estilo == .vision || rotulo == "NIGHTSHOT")
            let punto = CGPoint(
                x: centrado
                    ? (ancho - medida.width) / 2
                    : ancho - medida.width - margen,
                y: alto - medida.height - (centrado ? margen * 1.8 : margen)
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
        estilo: EstiloFecha = .dazz,
        rotulo: String? = nil
    ) -> CIImage? {
        guard tamano.width > 1, tamano.height > 1 else { return nil }

        let texto = textoCompleto(modo, fecha: fecha, rotulo: rotulo)
        guard !texto.isEmpty else { return nil }

        let esDazz = estilo.conBrillo
        let tamanoFuente = max(tamano.width * (esDazz ? 0.036 : 0.042), 10)
        let letras = piezas(texto, tamanoFuente: tamanoFuente, estilo: estilo)

        let medida = medida(letras.principal)
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

    /// Mide el texto ya compuesto, contando los saltos de linea del rotulo.
    private static func medida(_ texto: NSAttributedString) -> CGSize {
        let caja = texto.boundingRect(
            with: CGSize(width: 10_000, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return CGSize(width: ceil(caja.width), height: ceil(caja.height))
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

        let parrafo = NSMutableParagraphStyle()
        parrafo.lineSpacing = max(tamanoFuente * estilo.renglon, 1)

        let principal = NSAttributedString(
            string: texto,
            attributes: [
                .font: fuente,
                .kern: interletra,
                .foregroundColor: estilo.color,
                .paragraphStyle: parrafo
            ]
        )
        let brillo = NSAttributedString(
            string: texto,
            attributes: [
                .font: fuente,
                .kern: interletra,
                .foregroundColor: estilo.color.withAlphaComponent(0.45),
                .paragraphStyle: parrafo
            ]
        )
        let sombra = NSAttributedString(
            string: texto,
            attributes: [
                .font: fuente,
                .kern: interletra,
                .foregroundColor: UIColor.black.withAlphaComponent(0.5),
                .paragraphStyle: parrafo
            ]
        )

        return (principal, brillo, sombra)
    }
}
