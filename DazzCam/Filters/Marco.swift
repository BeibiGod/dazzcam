import CoreImage
import UIKit

/// Marco de papel alrededor de la foto. Los mismos seis que trae Framed:
/// PLAIN, SPECS, WHITE, PAPER, INSTANT, FILM.
/// El borde come un poco de la orilla: la proporcion de la foto no cambia.
enum Marco: String, CaseIterable, Identifiable, Codable {
    case plain
    case specs
    case white
    case paper
    case instant
    case film

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .plain: return "PLAIN"
        case .specs: return "SPECS"
        case .white: return "WHITE"
        case .paper: return "PAPER"
        case .instant: return "INSTANT"
        case .film: return "FILM"
        }
    }

    /// Dibuja el marco encima de la foto ya procesada.
    func aplicar(a imagen: UIImage) -> UIImage {
        guard self != .plain,
              imagen.size.width > 1,
              imagen.size.height > 1
        else { return imagen }

        let ancho = imagen.size.width
        let alto = imagen.size.height

        // Margen de cada lado, en proporcion al lado mas corto.
        var arriba: CGFloat = 0.05
        var abajo: CGFloat = 0.05
        var lados: CGFloat = 0.05
        var fondo = UIColor.white

        switch self {
        case .plain:
            return imagen
        case .white:
            arriba = 0.045
            abajo = 0.045
            lados = 0.045
        case .paper:
            fondo = UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1)
        case .instant:
            // Polaroid: blanco y abajo mas ancho.
            arriba = 0.05
            lados = 0.05
            abajo = 0.12
        case .film:
            fondo = .black
            arriba = 0.055
            abajo = 0.055
            lados = 0.045
        case .specs:
            // Marco de "origen": blanco, abajo ancho para la linea de datos.
            arriba = 0.05
            lados = 0.05
            abajo = 0.14
        }

        let corto = min(ancho, alto)
        let margenArriba = corto * arriba
        let margenAbajo = corto * abajo
        let margenLados = corto * lados

        let destino = CGRect(
            x: margenLados,
            y: margenArriba,
            width: max(1, ancho - margenLados * 2),
            height: max(1, alto - margenArriba - margenAbajo)
        )

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = imagen.scale
        formato.opaque = true

        return UIGraphicsImageRenderer(size: imagen.size, format: formato).image { contexto in
            let cg = contexto.cgContext
            fondo.setFill()
            cg.fill(CGRect(origin: .zero, size: imagen.size))

            imagen.draw(in: destino)

            if self == .film {
                // Perforaciones arriba y abajo, en la banda negra.
                UIColor.white.withAlphaComponent(0.85).setFill()
                let altoAgujero = margenArriba * 0.42
                let anchoAgujero = altoAgujero * 1.5
                var x = margenLados * 0.5

                while x + anchoAgujero < ancho - margenLados * 0.5 {
                    let agujero = CGRect(
                        x: x,
                        y: (margenArriba - altoAgujero) / 2,
                        width: anchoAgujero,
                        height: altoAgujero
                    )
                    UIBezierPath(
                        roundedRect: agujero,
                        cornerRadius: altoAgujero * 0.25
                    ).fill()

                    let espejo = agujero.offsetBy(dx: 0, dy: alto - margenArriba)
                    UIBezierPath(
                        roundedRect: espejo,
                        cornerRadius: altoAgujero * 0.25
                    ).fill()

                    x += anchoAgujero * 2
                }
            }
        }
    }

    /// Nombre del iPhone, ej. "iPhone 13 Pro Max".
    private static func nombreDispositivo() -> String {
        var info = utsname()
        uname(&info)
        let id = withUnsafePointer(to: &info.machine) { puntero in
            puntero.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }

        let mapa: [String: String] = [
            "iPhone14,5": "iPhone 13",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max"
        ]

        return mapa[id] ?? id
    }
}
