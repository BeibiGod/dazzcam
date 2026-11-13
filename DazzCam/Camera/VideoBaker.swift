import AVFoundation
import CoreImage
import CoreTransferable
import UIKit
import UniformTypeIdentifiers

/// Un video elegido en la fototeca, copiado a una carpeta temporal
/// para poder leerlo sin pedir permisos extra.
struct VideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { recibido in
            let destino = FileManager.default.temporaryDirectory
                .appendingPathComponent("beibi-entrada-\(UUID().uuidString).mov")

            try? FileManager.default.removeItem(at: destino)
            try FileManager.default.copyItem(at: recibido.file, to: destino)

            return VideoFile(url: destino)
        }
    }
}

/// Hornea el look elegido dentro de un video, con su sonido original.
/// Sirve para los videos que graba la app y para los que ya tenias.
enum VideoBaker {

    enum ErrorVideo: LocalizedError {
        case sinExportador
        case noSePudo(String)

        var errorDescription: String? {
            switch self {
            case .sinExportador:
                return "No pude preparar el video"
            case .noSePudo(let detalle):
                return detalle
            }
        }
    }

    /// Composicion que aplica el filtro cuadro por cuadro y quema la fecha.
    /// Se usa igual para exportar y para verlo en el reproductor.
    static func composicion(
        _ asset: AVAsset,
        preset: FilterPreset,
        controles: ControlesLook = ControlesLook(),
        sello: SelloFecha = .apagado,
        fecha: Date = Date()
    ) -> AVVideoComposition {
        let capa = CapaFecha(modo: sello, fecha: fecha)

        return AVVideoComposition(asset: asset) { peticion in
            let filtrada = FilterEngine.cadena(
                preset,
                entrada: peticion.sourceImage,
                controles: controles
            )

            let base = filtrada ?? peticion.sourceImage
            peticion.finish(with: capa.aplicar(sobre: base), context: nil)
        }
    }

    /// Exporta una copia filtrada a un archivo temporal .mp4.
    static func exportar(
        _ url: URL,
        preset: FilterPreset,
        controles: ControlesLook = ControlesLook(),
        sello: SelloFecha = .apagado,
        fecha: Date = Date()
    ) async throws -> URL {
        let asset = AVURLAsset(url: url)

        guard let exportador = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ErrorVideo.sinExportador
        }

        let destino = FileManager.default.temporaryDirectory
            .appendingPathComponent("beibi-listo-\(UUID().uuidString).mp4")

        try? FileManager.default.removeItem(at: destino)

        exportador.outputURL = destino
        exportador.outputFileType = .mp4
        exportador.videoComposition = composicion(
            asset,
            preset: preset,
            controles: controles,
            sello: sello,
            fecha: fecha
        )
        exportador.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { (continuacion: CheckedContinuation<Void, Never>) in
            exportador.exportAsynchronously {
                continuacion.resume()
            }
        }

        if exportador.status != .completed {
            throw exportador.error ?? ErrorVideo.noSePudo("El video no se pudo procesar")
        }

        return destino
    }

    /// Saca un cuadro del video para las miniaturas y la vista previa.
    static func cuadro(de url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generador = AVAssetImageGenerator(asset: asset)
        generador.appliesPreferredTrackTransform = true
        generador.maximumSize = CGSize(width: 1080, height: 1080)

        let tiempo = CMTime(seconds: 0.2, preferredTimescale: 600)

        return await withCheckedContinuation { (continuacion: CheckedContinuation<UIImage?, Never>) in
            generador.generateCGImagesAsynchronously(forTimes: [NSValue(time: tiempo)]) { _, cg, _, _, _ in
                if let cg = cg {
                    continuacion.resume(returning: UIImage(cgImage: cg))
                } else {
                    continuacion.resume(returning: nil)
                }
            }
        }
    }
}

/// Guarda la fecha ya dibujada para no rehacerla en cada cuadro del video.
/// Es la misma durante todo el clip, como en una camara de rollo.
private final class CapaFecha {

    private let modo: SelloFecha
    private let fecha: Date
    private let cerrojo = NSLock()
    private var cache: (tamano: CGSize, imagen: CIImage)?

    init(modo: SelloFecha, fecha: Date) {
        self.modo = modo
        self.fecha = fecha
    }

    func aplicar(sobre imagen: CIImage) -> CIImage {
        guard modo.encendido else { return imagen }

        let extent = imagen.extent
        guard extent.width > 1, extent.height > 1 else { return imagen }
        guard let capa = capaPara(tamano: extent.size) else { return imagen }

        let margen = max(extent.width * 0.032, 2)
        let x = extent.maxX - margen - capa.extent.width
        let y = extent.minY + margen

        let puesta = capa.transformed(
            by: CGAffineTransform(translationX: x, y: y)
        )
        return puesta.composited(over: imagen)
    }

    private func capaPara(tamano: CGSize) -> CIImage? {
        cerrojo.lock()
        defer { cerrojo.unlock() }

        if let cache = cache, cache.tamano == tamano {
            return cache.imagen
        }

        guard let creada = SelloFecha.capaVideo(modo, fecha: fecha, tamano: tamano) else {
            return nil
        }

        cache = (tamano, creada)
        return creada
    }
}