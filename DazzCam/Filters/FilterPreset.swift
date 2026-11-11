import Foundation

/// Los filtros disponibles. Paso 5: se aplican a la foto ya tomada.
enum FilterPreset: String, CaseIterable, Identifiable {
    case original = "Original"
    case calido = "Calido"
    case frio = "Frio"
    case vintage = "Vintage"
    case blancoYNegro = "B y N"

    var id: String { rawValue }
}
