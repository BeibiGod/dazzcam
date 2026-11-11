import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Aplica filtros de CoreImage a una foto ya capturada.
enum FilterEngine {

    private static let contexto = CIContext()

    static func aplicar(_ preset: FilterPreset, a imagen: UIImage) -> UIImage {
        guard preset != .original else { return imagen }

        let base = normalizar(imagen)
        guard let entrada = CIImage(image: base) else { return imagen }
        guard let salida = cadena(preset, entrada: entrada) else { return imagen }

        guard let cg = contexto.createCGImage(salida, from: entrada.extent) else {
            return imagen
        }
        return UIImage(cgImage: cg, scale: base.scale, orientation: .up)
    }

    // MARK: - Cadenas de filtros

    static func cadena(_ preset: FilterPreset, entrada: CIImage) -> CIImage? {
        switch preset {
        case .original:
            return entrada

        case .calido:
            let temperatura = CIFilter.temperatureAndTint()
            temperatura.inputImage = entrada
            temperatura.neutral = CIVector(x: 6500, y: 0)
            temperatura.targetNeutral = CIVector(x: 8200, y: 25)

            let saturacion = CIFilter.colorControls()
            saturacion.inputImage = temperatura.outputImage
            saturacion.saturation = 1.12
            saturacion.contrast = 1.03
            return saturacion.outputImage

        case .frio:
            let temperatura = CIFilter.temperatureAndTint()
            temperatura.inputImage = entrada
            temperatura.neutral = CIVector(x: 6500, y: 0)
            temperatura.targetNeutral = CIVector(x: 5000, y: -10)

            let saturacion = CIFilter.colorControls()
            saturacion.inputImage = temperatura.outputImage
            saturacion.saturation = 1.05
            saturacion.contrast = 1.05
            return saturacion.outputImage

        case .vintage:
            let transferencia = CIFilter.photoEffectTransfer()
            transferencia.inputImage = entrada
            guard let intermedia = transferencia.outputImage else { return entrada }

            let vineta = CIFilter.vignette()
            vineta.inputImage = intermedia
            vineta.intensity = 1.1
            vineta.radius = 2.2
            return vineta.outputImage

        case .blancoYNegro:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = entrada
            guard let intermedia = mono.outputImage else { return entrada }

            let contraste = CIFilter.colorControls()
            contraste.inputImage = intermedia
            contraste.contrast = 1.15
            return contraste.outputImage
        }
    }

    // MARK: - Utilidades

    /// Redibuja la imagen derecha para evitar fotos torcidas tras filtrar.
    static func normalizar(_ imagen: UIImage) -> UIImage {
        guard imagen.imageOrientation != .up else { return imagen }

        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = imagen.scale
        formato.opaque = true
        let renderer = UIGraphicsImageRenderer(size: imagen.size, format: formato)

        return renderer.image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: imagen.size))
        }
    }
}
