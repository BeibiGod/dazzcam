import Foundation
import SwiftUI

/// Los dos idiomas de la app. El español es el original y el inglés vive en
/// `en.lproj`. Se puede cambiar en cualquier momento desde el engranaje.
enum Idioma: String, CaseIterable, Identifiable, Codable {
    case es
    case en

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .es: return "Español"
        case .en: return "English"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// Clave donde se guarda la eleccion.
    static let clave = "beibi.idioma"

    static var actual: Idioma {
        Idioma(rawValue: UserDefaults.standard.string(forKey: clave) ?? "es") ?? .es
    }

    /// Bundle del idioma elegido. El español usa el bundle principal; sus
    /// textos son las mismas claves, asi que nunca se mezcla con el ingles.
    var bundle: Bundle {
        switch self {
        case .es:
            if let ruta = Bundle.main.path(forResource: "es", ofType: "lproj"),
               let elegido = Bundle(path: ruta) {
                return elegido
            }
            return .main
        case .en:
            if let ruta = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let elegido = Bundle(path: ruta) {
                return elegido
            }
            return .main
        }
    }
}

/// Texto que respeta el idioma elegido aunque el iPhone este configurado en
/// otro. Reemplaza a `String(localized:)` en todo el codigo.
func L(_ clave: String, _ argumentos: CVarArg...) -> String {
    let formato = Idioma.actual.bundle.localizedString(
        forKey: clave,
        value: clave,
        table: nil
    )

    guard !argumentos.isEmpty else { return formato }
    return String(format: formato, arguments: argumentos)
}
