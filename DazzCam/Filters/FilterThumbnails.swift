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
        guard ancho > 0, alto > 0 else { return imagen }

        let menor = min(ancho, alto)
        let recorte = CGRect(
            x: (ancho - menor) / 2,
            y: (alto - menor) / 2,
            width: menor,
            height: menor
        )

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: lado, height: lado),
            format: formato
        )

        return renderer.image { _ in
            normal.draw(
                in: CGRect(x: 0, y: 0, width: lado, height: lado),
                from: recorte
            )
        }
    }
}
