import CoreImage
import UIKit

/// CIRCLES: doble exposicion fotografica real.
/// Dos fotos se funden en UNA sola imagen; la 2a ocupa toda el area (no es
/// miniatura, no collage, no Picture-in-Picture). UN motor para ambos flujos.
enum DuoFoto {
    static let contexto = CIContext()

    /// `lado` de salida. Por defecto la mayor resolucion posible.
    static func combinar(
        _ a: UIImage,
        _ b: UIImage,
        lado: CGFloat? = nil,
        composicion: CirclesComposition = CirclesComposition()
    ) -> UIImage {
        let salida = lado ?? max(1080, pixelSize(a), pixelSize(b))
        let extento = CGRect(x: 0, y: 0, width: salida, height: salida)

        let primera = composicion.swapOrder ? b : a
        let segunda = composicion.swapOrder ? a : b

        let fondo = escalar(CI(primera), a: salida, factor: 1.0, offset: .zero, extento: extento)
        let capa = escalar(
            CI(segunda),
            a: salida,
            factor: composicion.scale2,
            offset: composicion.offset2,
            extento: extento
        )

        var imagen = mezclar(
            capa,
            sobre: fondo,
            blend: composicion.blend,
            intensidad: composicion.intensity,
            mascaraLuminancia: composicion.luminanceMask,
            extento: extento
        ) ?? capa

        imagen = imagen.cropped(to: extento)

        guard let cg = contexto.createCGImage(imagen, from: extento) else {
            return renderSimple(primera, segunda, salida: salida, composicion: composicion)
        }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    // MARK: - CoreImage

    private static func CI(_ imagen: UIImage) -> CIImage {
        CIImage(image: imagen) ?? CIImage()
    }

    private static func escalar(
        _ imagen: CIImage,
        a salida: CGFloat,
        factor: CGFloat,
        offset: CGPoint,
        extento: CGRect
    ) -> CIImage {
        let w = max(imagen.extent.width, 1)
        let h = max(imagen.extent.height, 1)
        let escala = max(salida / w, salida / h) * max(factor, 0.05)

        var out = imagen.transformed(by: CGAffineTransform(
            translationX: -imagen.extent.minX, y: -imagen.extent.minY
        ))
        out = out.transformed(by: CGAffineTransform(scaleX: escala, y: escala))

        let tx = (salida - out.extent.width) / 2 + offset.x * salida
        let ty = (salida - out.extent.height) / 2 + offset.y * salida
        out = out.transformed(by: CGAffineTransform(translationX: tx, y: ty))

        return out.cropped(to: extento)
    }

    private static func mezclar(
        _ capa: CIImage,
        sobre fondo: CIImage,
        blend: CirclesComposition.Blend,
        intensidad: CGFloat,
        mascaraLuminancia: Bool,
        extento: CGRect
    ) -> CIImage? {
        guard let filtro = CIFilter(name: blend.filtro) else { return capa }
        filtro.setValue(capa, forKey: kCIInputImageKey)
        filtro.setValue(fondo, forKey: "inputBackgroundImage")
        guard var mezcla = filtro.outputImage else { return capa }

        // contraste leve para que los detalles interactuen
        if let contraste = CIFilter(name: "CIColorControls") {
            contraste.setValue(mezcla, forKey: kCIInputImageKey)
            contraste.setValue(1.08, forKey: kCIInputContrastKey)
            if let r = contraste.outputImage { mezcla = r }
        }

        let t = max(0, min(1, intensidad))

        guard let mascara = CIFilter(name: "CIBlendWithMask") else { return mezcla }
        mascara.setValue(mezcla, forKey: kCIInputImageKey)
        mascara.setValue(fondo, forKey: "inputBackgroundImage")

        if mascaraLuminancia {
            // mascara de luminancia de la 2a, multiplicada por intensidad
            var lum = capa
            if let toAlpha = CIFilter(name: "CIMaskToAlpha") {
                toAlpha.setValue(capa, forKey: kCIInputImageKey)
                lum = toAlpha.outputImage ?? capa
            }
            if let mul = CIFilter(name: "CIMultiplyBlendMode") {
                mul.setValue(lum, forKey: kCIInputImageKey)
                mul.setValue(solido(t, extento), forKey: "inputBackgroundImage")
                mascara.setValue(mul.outputImage ?? solido(t, extento), forKey: "inputMaskImage")
            } else {
                mascara.setValue(solido(t, extento), forKey: "inputMaskImage")
            }
        } else {
            mascara.setValue(solido(t, extento), forKey: "inputMaskImage")
        }

        return mascara.outputImage ?? mezcla
    }

    private static func solido(_ v: CGFloat, _ extento: CGRect) -> CIImage {
        CIImage(color: CIColor(red: v, green: v, blue: v, alpha: 1)).cropped(to: extento)
    }

    // MARK: - Fallback UIKit

    private static func renderSimple(
        _ a: UIImage, _ b: UIImage, salida: CGFloat, composicion: CirclesComposition
    ) -> UIImage {
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = true
        let medida = CGSize(width: salida, height: salida)
        return UIGraphicsImageRenderer(size: medida, format: formato).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: medida))
            dibujar(a, en: CGRect(origin: .zero, size: medida))
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.setAlpha(composicion.intensity)
            ctx?.setBlendMode(.screen)
            dibujar(b, en: CGRect(origin: .zero, size: medida))
            ctx?.setAlpha(1); ctx?.setBlendMode(.normal)
        }
    }

    private static func dibujar(_ imagen: UIImage, en caja: CGRect) {
        let medida = imagen.size
        guard medida.width > 0, medida.height > 0 else { return }
        let escala = max(caja.width / medida.width, caja.height / medida.height)
        let ancho = medida.width * escala, alto = medida.height * escala
        let destino = CGRect(x: caja.midX - ancho / 2, y: caja.midY - alto / 2, width: ancho, height: alto)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState(); UIBezierPath(rect: caja).addClip(); imagen.draw(in: destino); ctx?.restoreGState()
    }

    private static func pixelSize(_ i: UIImage) -> CGFloat {
        max(i.size.width, i.size.height) * i.scale
    }
}
