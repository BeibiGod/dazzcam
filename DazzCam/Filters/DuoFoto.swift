import UIKit

/// CIRCLES: dos fotos se vuelven una sola sobre el mismo cuadro.
enum DuoFoto {
    /// Un solo lienzo cuadrado: la 1a llena el cuadro, la 2a encima en una
    /// esquina con marquita. (No son dos archivos ni lado a lado.)
    static func combinar(_ a: UIImage, _ b: UIImage, lado: CGFloat = 1080) -> UIImage {
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = true
        let medida = CGSize(width: lado, height: lado)

        return UIGraphicsImageRenderer(size: medida, format: formato).image { _ in
            // Fondo blanco por si algo sobra.
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: medida))

            // 1a foto: llena todo el cuadro.
            dibujar(a, en: CGRect(origin: .zero, size: medida))

            // 2a foto: encima, esquina inferior derecha, con marquita.
            let lado2 = lado * 0.45
            let margen = lado * 0.05
            let caja2 = CGRect(
                x: lado - lado2 - margen,
                y: lado - lado2 - margen,
                width: lado2,
                height: lado2
            )

            // Borde blanco alrededor de la segunda.
            UIColor.white.setFill()
            UIRectFill(caja2.insetBy(dx: -margen * 0.5, dy: -margen * 0.5))
            dibujar(b, en: caja2)
        }
    }

    private static func dibujar(_ imagen: UIImage, en caja: CGRect) {
        let medida = imagen.size
        guard medida.width > 0, medida.height > 0 else { return }

        let escala = max(caja.width / medida.width, caja.height / medida.height)
        let ancho = medida.width * escala
        let alto = medida.height * escala
        let destino = CGRect(
            x: caja.midX - ancho / 2,
            y: caja.midY - alto / 2,
            width: ancho,
            height: alto
        )

        let contexto = UIGraphicsGetCurrentContext()
        contexto?.saveGState()
        UIBezierPath(rect: caja).addClip()
        imagen.draw(in: destino)
        contexto?.restoreGState()
    }
}
