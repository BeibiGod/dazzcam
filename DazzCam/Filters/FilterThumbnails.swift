import Combine
import UIKit

/// Genera una muestra pequena de cada camara usando el primer cuadro real
/// de la camara. Asi el usuario ve como quedaria la foto antes de tomarla.
final class FilterThumbnails: ObservableObject {

    @Published private(set) var muestras: [FilterPreset: UIImage] = [:]
    @Published private(set) var lista = false

    private let cola = DispatchQueue(label: "com.diego.dazzcam.miniaturas", qos: .utility)

    func generar(desde imagen: UIImage) {
        guard !lista else { return }
        lista = true

        let chica = FilterThumbnails.reducir(imagen, lado: 128)

        cola.async { [weak self] in
            guard let self = self else { return }

            var resultado: [FilterPreset: UIImage] = [:]
            for preset in FilterPreset.allCases {
                resultado[preset] = FilterEngine.aplicar(preset, a: chica)
            }

            DispatchQueue.main.async {
                self.muestras = resultado
            }
        }
    }

    /// Recorta al centro en cuadrado y reduce.
    static func reducir(_ imagen: UIImage, lado: CGFloat) -> UIImage {
        let normal = FilterEngine.normalizar(imagen)
        let ancho = normal.size.width
        let alto = normal.size.height
        guard ancho > 0, alto > 0, let cg = normal.cgImage else { return imagen }

        let ladoPx = min(CGFloat(cg.width), CGFloat(cg.height))
        guard ladoPx > 0 else { return imagen }

        let recorte = CGRect(
            x: (CGFloat(cg.width) - ladoPx) / 2,
            y: (CGFloat(cg.height) - ladoPx) / 2,
            width: ladoPx,
            height: ladoPx
        )
        guard let recortada = cg.cropping(to: recorte) else { return imagen }

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: lado, height: lado),
            format: formato
        )

        return renderer.image { _ in
            UIImage(cgImage: recortada, scale: 1, orientation: .up)
                .draw(in: CGRect(x: 0, y: 0, width: lado, height: lado))
        }
    }
}
