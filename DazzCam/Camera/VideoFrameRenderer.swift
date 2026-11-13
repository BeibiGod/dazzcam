import CoreImage
import CoreVideo
import UIKit

/// Convierte un frame de video de la camara en una imagen ya filtrada.
///
/// El frame llega a resolucion completa (la camara entrega mas de 1920 px).
/// Filtrar eso cuadro por cuadro en el telefono baja los fps a la mitad, asi
/// que primero se reduce a un tamano de pantalla y despues se aplica el look.
final class VideoFrameRenderer {

    private let contexto = CIContext(options: [.cacheIntermediates: false])

    /// Lado mayor al que se reduce el frame antes de filtrar.
    private let ladoMayor: CGFloat = 1080

    func renderizar(
        _ buffer: CVPixelBuffer,
        preset: FilterPreset,
        controles: ControlesLook
    ) -> UIImage? {
        let entrada = CIImage(cvPixelBuffer: buffer)
        let chica = reducir(entrada)

        guard let salida = FilterEngine.cadena(preset, entrada: chica, controles: controles) else {
            return nil
        }
        guard let cg = contexto.createCGImage(salida, from: salida.extent) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    /// Escala el frame solo si es mas grande que `ladoMayor`.
    private func reducir(_ imagen: CIImage) -> CIImage {
        let ancho = imagen.extent.width
        let alto = imagen.extent.height
        let mayor = max(ancho, alto)

        guard mayor > ladoMayor, mayor > 0 else { return imagen }

        let factor = ladoMayor / mayor
        let escalada = imagen.transformed(
            by: CGAffineTransform(scaleX: factor, y: factor)
        )
        return escalada
    }
}
