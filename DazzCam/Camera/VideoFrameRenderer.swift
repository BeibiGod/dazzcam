import CoreImage
import CoreVideo
import UIKit

/// Convierte un frame de video de la camara en una imagen ya filtrada.
final class VideoFrameRenderer {

    private let contexto = CIContext(options: [.cacheIntermediates: false])

    func renderizar(_ buffer: CVPixelBuffer, preset: FilterPreset) -> UIImage? {
        let entrada = CIImage(cvPixelBuffer: buffer)
        guard let salida = FilterEngine.cadena(preset, entrada: entrada) else {
            return nil
        }
        guard let cg = contexto.createCGImage(salida, from: entrada.extent) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}
