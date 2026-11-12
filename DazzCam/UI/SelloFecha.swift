import Foundation
import UIKit

/// Marca de fecha y hora, como las camaras viejitas.
enum SelloFecha: String, CaseIterable {
    case apagado
    case fecha
    case fechaHora

    var etiqueta: String {
        switch self {
        case .apagado: return "OFF"
        case .fecha: return "FECHA"
        case .fechaHora: return "F+HORA"
        }
    }

    var siguiente: SelloFecha {
        switch self {
        case .apagado: return .fecha
        case .fecha: return .fechaHora
        case .fechaHora: return .apagado
        }
    }

    var encendido: Bool { self != .apagado }

    /// Texto tipo camara de los 90:  '26 11 12   /   '26 11 12 18:40
    static func texto(_ modo: SelloFecha, fecha: Date = Date()) -> String {
        switch modo {
        case .apagado:
            return ""

        case .fecha:
            return formatear(fecha, patron: "'yy MM dd")

        case .fechaHora:
            return formatear(fecha, patron: "'yy MM dd HH:mm")
        }
    }

    private static func formatear(_ fecha: Date, patron: String) -> String {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "en_US_POSIX")
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
            let tamano = max(ancho * 0.042, 10)
            let fuente = UIFont.monospacedSystemFont(ofSize: tamano, weight: .bold)

            let principal = NSAttributedString(
                string: texto,
                attributes: [
                    .font: fuente,
                    .foregroundColor: UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 0.95)
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
            principal.draw(at: punto)
        }
    }
}
