import Foundation

/// Guarda lo ultimo que el usuario dejo puesto: camara, fecha y look.
/// Asi al volver a abrir la app sigue todo como lo dejo.
enum Preferencias {
    private static let clave = "beibi.ajustes.v1"

    private struct Guardado: Codable {
        var preset: FilterPreset
        var sello: SelloFecha
        var controles: ControlesLook
    }

    static func cargar() -> (
        preset: FilterPreset,
        sello: SelloFecha,
        controles: ControlesLook
    )? {
        guard let datos = UserDefaults.standard.data(forKey: clave),
              let guardado = try? JSONDecoder().decode(Guardado.self, from: datos)
        else { return nil }

        return (guardado.preset, guardado.sello, guardado.controles)
    }

    static func guardar(
        preset: FilterPreset,
        sello: SelloFecha,
        controles: ControlesLook
    ) {
        let guardado = Guardado(
            preset: preset,
            sello: sello,
            controles: controles
        )
        guard let datos = try? JSONEncoder().encode(guardado) else { return }
        UserDefaults.standard.set(datos, forKey: clave)
    }
}
