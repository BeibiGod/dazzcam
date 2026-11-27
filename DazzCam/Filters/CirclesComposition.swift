import CoreGraphics

/// Parametros de la doble exposicion Circles.
struct CirclesComposition {
    enum Blend: String, CaseIterable, Identifiable {
        case screen, lighten, multiply, overlay
        var id: String { rawValue }
        var nombre: String { rawValue.uppercased() }
        /// Filtro CoreImage.
        var filtro: String {
            switch self {
            case .screen: return "CIScreenBlendMode"
            case .lighten: return "CILightenBlendMode"
            case .multiply: return "CIMultiplyBlendMode"
            case .overlay: return "CIOverlayBlendMode"
            }
        }
    }

    var swapOrder: Bool = false
    var scale2: CGFloat = 1.0          // 2a ocupa el area; NO miniatura
    var offset2: CGPoint = .zero       // posicion de la 2a (fraccion del lado)
    var intensity: CGFloat = 1.0       // 0 = solo 1a, 1 = mezcla completa
    var blend: Blend = .screen
    var luminanceMask: Bool = true     // mascara de luminancia
}
