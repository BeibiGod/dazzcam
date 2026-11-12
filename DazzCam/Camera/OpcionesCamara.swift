import CoreGraphics
import Foundation

/// Como se ve el visor y como sale la foto.
enum Proporcion: String, CaseIterable {
    case completa
    case dieciseisNueve

    var etiqueta: String {
        switch self {
        case .completa: return "4:3"
        case .dieciseisNueve: return "16:9"
        }
    }

    /// ancho / alto de la foto final. nil = sin recorte.
    var relacion: CGFloat? {
        switch self {
        case .completa: return nil
        case .dieciseisNueve: return 9.0 / 16.0
        }
    }

    var alterna: Proporcion {
        switch self {
        case .completa: return .dieciseisNueve
        case .dieciseisNueve: return .completa
        }
    }
}

/// Cuenta regresiva antes de disparar.
enum Temporizador: String, CaseIterable {
    case apagado
    case tres
    case diez

    var etiqueta: String {
        switch self {
        case .apagado: return "OFF"
        case .tres: return "3s"
        case .diez: return "10s"
        }
    }

    var segundos: Int {
        switch self {
        case .apagado: return 0
        case .tres: return 3
        case .diez: return 10
        }
    }

    var siguiente: Temporizador {
        switch self {
        case .apagado: return .tres
        case .tres: return .diez
        case .diez: return .apagado
        }
    }
}
