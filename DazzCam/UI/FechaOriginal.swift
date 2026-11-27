import Foundation
import ImageIO

/// Lee la fecha de creacion original de una foto (EXIF) para AUTOMATIC.
enum FechaOriginal {
    /// `DateTimeOriginal` / `DateTimeDigitized` / `DateTime`. nil si no hay.
    static func leer(de data: Data) -> Date? {
        guard let fuente = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(fuente, 0, nil) as? [CFString: Any]
        else { return nil }

        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

        let candidatos = [
            exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
            exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
            tiff?[kCGImagePropertyTIFFDateTime] as? String,
            props[kCGImagePropertyTIFFDateTime] as? String
        ].compactMap { $0 }

        for texto in candidatos {
            if let fecha = parsear(texto) { return fecha }
        }
        return nil
    }

    /// EXIF usa "yyyy:MM:dd HH:mm:ss"; acepta tambien ISO-8601.
    private static func parsear(_ texto: String) -> Date? {
        let formatos = ["yyyy:MM:dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        let formateador = DateFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.timeZone = TimeZone.current

        for patron in formatos {
            formateador.dateFormat = patron
            if let fecha = formateador.date(from: texto) { return fecha }
        }

        return ISO8601DateFormatter().date(from: texto)
    }
}
