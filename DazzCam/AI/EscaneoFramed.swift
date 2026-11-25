import CoreGraphics
import UIKit

/// Escaneo estilo Framed: la escena lee luz, contraste, color, horizonte y
/// caras, y devuelve el recuadro sujeto que conviene dejar. Todo procesado
/// en el dispositivo, igual que en la app de Framed: nada se sube a internet.
enum EscaneoFramed {

    /// Lo que un escaneo de la escena devuelve.
    struct Escaneo {
        var puntaje: Int
        var resumen: String
        var consejos: [String]
        var luz: Int
        var contraste: Int
        var color: Int
        var horizonte: Int
        var caras: Int
        var etiqueta: String
        /// Recuadro del sujeto en coordenadas de foto (0 a 1, arriba a la
        /// izquierda).
        var sujeto: CGRect
        var guia: Guia?
    }

    /// Escanea una imagen y devuelve las medidas de la escena y el recuadro.
    static func escanear(_ imagen: UIImage) async -> Escaneo? {
        guard let analisis = await AestheticAnalyzer.analizar(imagen) else { return nil }

        return Escaneo(
            puntaje: analisis.puntaje,
            resumen: analisis.resumen,
            consejos: analisis.consejos,
            luz: analisis.luz,
            contraste: analisis.contraste,
            color: analisis.color,
            horizonte: analisis.horizonte,
            caras: analisis.caras,
            etiqueta: analisis.etiqueta,
            sujeto: analisis.guia?.sujeto ?? CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            guia: analisis.guia
        )
    }
}
