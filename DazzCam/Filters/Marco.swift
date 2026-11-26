import CoreImage
import UIKit

/// Marco de papel alrededor de la foto, como los que trae Framed.
/// El borde come un poco de la orilla: la proporcion de la foto no cambia.
enum Marco: String, CaseIterable, Identifiable, Codable {
    // Framed: Polaroid, Paper, Spots, Negative, Film, Instant, Digital,
    // White, Postcard, Black, Floral + el marco "shot on iPhone".
    case ninguno
    case polaroid
    case papel
    case puntos
    case negativo
    case film
    case instantaneo
    case digital
    case blanco
    case postal
    case negro
    case floral
    case nombre

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .ninguno: return "SIN MARCO"
        case .polaroid: return "POLAROID"
        case .papel: return "PAPEL"
        case .puntos: return "PUNTOS"
        case .negativo: return "NEGATIVO"
        case .film: return "FILM"
        case .instantaneo: return "INSTANTANEO"
        case .digital: return "DIGITAL"
        case .blanco: return "BLANCO"
        case .postal: return "POSTAL"
        case .negro: return "NEGRO"
        case .floral: return "FLORAL"
        case .nombre: return "SHOT ON"
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
        case .papel, .puntos, .floral:
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
        case .negativo:
            fondo = .white
            arriba = 0.045
            abajo = 0.045
            lados = 0.045
        case .instantaneo:
            arriba = 0.05
            lados = 0.05
            abajo = 0.12
        case .digital:
            fondo = .black
            arriba = 0.02
            abajo = 0.02
            lados = 0.02
        case .blanco:
            arriba = 0.045
            abajo = 0.045
            lados = 0.045
        case .negro:
            fondo = .black
            arriba = 0.045
            abajo = 0.045
            lados = 0.045
        case .nombre:
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

        let base = (self == .negativo) ? invertida(imagen) : imagen

        return UIGraphicsImageRenderer(size: imagen.size, format: formato).image { contexto in
            let cg = contexto.cgContext
            fondo.setFill()
            cg.fill(CGRect(origin: .zero, size: imagen.size))

            base.draw(in: destino)

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

            if self == .puntos {
                // Puntos pequenos dispersos en el papel.
                UIColor.black.withAlphaComponent(0.14).setFill()
                var azar: UInt64 = 0x9E37_79B9_7F4A_7C15
                let total = Int((ancho + alto) / corto * 24)
                for _ in 0..<max(1, total) {
                    azar ^= azar >> 33
                    azar = azar &* 0xFF51_AFD7_ED55_8CCD
                    let px = CGFloat(azar % 10_000) / 10_000 * ancho
                    azar ^= azar >> 29
                    azar = azar &* 0xC4CE_B9FE_1A85_EC53
                    let py = CGFloat(azar % 10_000) / 10_000 * alto
                    let punto = CGRect(x: px, y: py, width: 1.5, height: 1.5)
                    // solo fuera de la foto
                    if !destino.intersects(punto) {
                        UIBezierPath(ovalIn: punto).fill()
                    }
                }
            }

            if self == .floral {
                // Petalos pequenos repetidos en los margenes.
                UIColor(red: 0.82, green: 0.45, blue: 0.55, alpha: 0.8).setFill()
                let r = corto * 0.012
                let paso = r * 4
                var posiciones: [CGPoint] = []
                var x = r
                while x < ancho - r {
                    posiciones.append(CGPoint(x: x, y: r))
                    posiciones.append(CGPoint(x: x, y: alto - r))
                    x += paso
                }
                var y = r
                while y < alto - r {
                    posiciones.append(CGPoint(x: r, y: y))
                    posiciones.append(CGPoint(x: ancho - r, y: y))
                    y += paso
                }
                for centro in posiciones where !destino.contains(centro) {
                    dibujarPetalos(en: centro, radio: r)
                }
            }

            if self == .nombre {
                // Shot on <dispositivo>, como los marcos de "origen".
                let texto = "SHOT ON " + Self.nombreDispositivo().uppercased()
                let atributos: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: max(9, margenAbajo * 0.28), weight: .semibold),
                    .foregroundColor: UIColor.black.withAlphaComponent(0.75),
                    .kern: 1.2
                ]
                let tamano = (texto as NSString).size(withAttributes: atributos)
                let punto = CGPoint(
                    x: (ancho - tamano.width) / 2,
                    y: alto - margenAbajo + (margenAbajo - tamano.height) / 2
                )
                (texto as NSString).draw(at: punto, withAttributes: atributos)
            }
        }
    }

    private func dibujarPetalos(en centro: CGPoint, radio r: CGFloat) {
        for angulo in stride(from: 0, to: 360, by: 90) {
            let rad = CGFloat(angulo) * .pi / 180
            let petalo = CGRect(
                x: centro.x + cos(rad) * r - r / 2,
                y: centro.y + sin(rad) * r - r / 2,
                width: r,
                height: r
            )
            UIBezierPath(ovalIn: petalo).fill()
        }
        UIColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: centro.x - r / 4, y: centro.y - r / 4, width: r / 2, height: r / 2)).fill()
    }

    private func invertida(_ imagen: UIImage) -> UIImage {
        guard let entrada = CIImage(image: imagen),
              let filtro = CIFilter(name: "CIColorInvert")
        else { return imagen }

        filtro.setValue(entrada, forKey: kCIInputImageKey)
        guard let salida = filtro.outputImage,
              let cg = CIContext().createCGImage(salida, from: salida.extent)
        else { return imagen }

        return UIImage(cgImage: cg, scale: imagen.scale, orientation: imagen.imageOrientation)
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
