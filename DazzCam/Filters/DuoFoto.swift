import UIKit

/// Duo: dos fotos se vuelven una sola, dos cuadritos juntos.
enum DuoFoto {
    /// Lado a lado, cada una en un cuadrado que llena su mitad.
    static func combinar(_ a: UIImage, _ b: UIImage, lado: CGFloat = 1080) -> UIImage {
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = true
        let medida = CGSize(width: lado * 2, height: lado)

        return UIGraphicsImageRenderer(size: medida, format: formato).image { _ in
            dibujar(a, en: CGRect(x: 0, y: 0, width: lado, height: lado))
            dibujar(b, en: CGRect(x: lado, y: 0, width: lado, height: lado))
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
