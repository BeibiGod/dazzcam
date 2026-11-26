import UIKit

/// Marco de papel alrededor de la foto, como los que trae Framed.
/// El borde come un poco de la orilla: la proporcion de la foto no cambia.
enum Marco: String, CaseIterable, Identifiable, Codable {
    case ninguno
    case polaroid
    case papel
    case postal
    case film
    case blanco
    case negro

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .ninguno: return "SIN MARCO"
        case .polaroid: return "POLAROID"
        case .papel: return "PAPEL"
        case .postal: return "POSTAL"
        case .film: return "FILM"
        case .blanco: return "BLANCO"
        case .negro: return "NEGRO"
        }
    }

    /// Dibuja el marco encima de la foto ya procesada.
    func aplicar(a imagen: UIImage) -> UIImage {
        guard self != .ninguno,
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
        case .ninguno:
            return imagen
        case .polaroid:
            // Abajo mas ancho: ahi va la firma en una polaroid de verdad.
            arriba = 0.055
            lados = 0.055
            abajo = 0.17
        case .papel:
            fondo = UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1)
        case .postal:
            arriba = 0.045
            abajo = 0.045
            lados = 0.045
        case .film:
            fondo = .black
            arriba = 0.055
            abajo = 0.055
            lados = 0.045
        case .blanco:
            arriba = 0.045
            abajo = 0.045
            lados = 0.045
        case .negro:
            fondo = .black
            arriba = 0.045
            abajo = 0.045
            lados = 0.045
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

            if self == .postal {
                // Linea fina por dentro, como las postales de antes.
                let linea = UIBezierPath(rect: destino.insetBy(dx: 1, dy: 1))
                UIColor.black.withAlphaComponent(0.18).setStroke()
                linea.lineWidth = 1
                linea.stroke()
            }

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
}
