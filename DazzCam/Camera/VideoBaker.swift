import AVFoundation
import CoreImage
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

    /// Composicion que aplica el filtro cuadro por cuadro.
    /// Se usa igual para exportar y para verlo en el reproductor.
    static func composicion(_ asset: AVAsset, preset: FilterPreset) -> AVVideoComposition {
        AVVideoComposition(asset: asset) { peticion in
            let filtrada = FilterEngine.cadena(preset, entrada: peticion.sourceImage)
            peticion.finish(with: filtrada ?? peticion.sourceImage, context: nil)
        }
    }

    /// Exporta una copia filtrada a un archivo temporal .mp4.
    static func exportar(_ url: URL, preset: FilterPreset) async throws -> URL {
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
        exportador.videoComposition = composicion(asset, preset: preset)
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