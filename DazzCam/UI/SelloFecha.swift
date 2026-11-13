import Foundation
import UIKit

/// Marca de fecha y hora, como las camaras viejitas.
enum SelloFecha: String, CaseIterable, Identifiable {
    case apagado
    case dazz
    case dazzHora
    case fecha
    case fechaHora

    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .apagado: return "OFF"
        case .dazz: return "DAZZ"
        case .dazzHora: return "DAZZ+H"
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
        case .fecha: return "12/11/2026"
        case .fechaHora: return "12/11/2026 2:28 AM"
        }
    }

    var siguiente: SelloFecha {
        switch self {
        case .apagado: return .dazz
        case .dazz: return .dazzHora
        case .dazzHora: return .fecha
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

    /// Quema la fecha en la foto, abajo a la derecha, en naranja.
    static func estampar(_ imagen: UIImage, modo: SelloFecha) -> UIImage {
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
            let esDazz = (modo == .dazz || modo == .dazzHora)
            let tamano = max(ancho * (esDazz ? 0.036 : 0.042), 10)
            let fuente = UIFont.monospacedSystemFont(ofSize: tamano, weight: .bold)

            let principal = NSAttributedString(
                string: texto,
                attributes: [
                    .font: fuente,
                    .foregroundColor: UIColor(red: 1.0, green: 0.58, blue: 0.16, alpha: 0.96)
                ]
            )
            let brillo = NSAttributedString(
                string: texto,
                attributes: [
                    .font: fuente,
                    .foregroundColor: UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.45)
                ]
            )
            let sombra = NSAttributedString(
                string: texto,
                attributes: [
                    .font: fuente,
                    .foregroundColor: UIColor.black.withAlphaComponent(0.5)
                ]
            )

            let medida = principal.size()
            let margen = ancho * 0.032
            let punto = CGPoint(
                x: ancho - medida.width - margen,
                y: alto - medida.height - margen
            )
            let corrimiento = max(tamano * 0.05, 1)

            sombra.draw(at: CGPoint(x: punto.x + corrimiento, y: punto.y + corrimiento))
            if esDazz {
                brillo.draw(at: CGPoint(x: punto.x - 0.6, y: punto.y - 0.6))
                brillo.draw(at: CGPoint(x: punto.x + 0.6, y: punto.y + 0.6))
            }
            principal.draw(at: punto)
        }
    }
}
