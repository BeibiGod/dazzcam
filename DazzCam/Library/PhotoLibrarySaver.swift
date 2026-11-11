import Photos
import UIKit

/// Guarda una imagen en la fototeca del iPhone pidiendo solo permiso de escritura.
enum PhotoLibrarySaver {

    enum ErrorGuardado: LocalizedError {
        case sinPermiso
        case fallo(String)

        var errorDescription: String? {
            switch self {
            case .sinPermiso:
                return "Sin permiso para guardar en la fototeca"
            case .fallo(let detalle):
                return detalle
            }
        }
    }

    static func guardar(_ imagen: UIImage) async throws {
        let estado = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch estado {
        case .authorized, .limited:
            break
        case .denied, .restricted:
            throw ErrorGuardado.sinPermiso
        case .notDetermined:
            let nuevo = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard nuevo == .authorized || nuevo == .limited else {
                throw ErrorGuardado.sinPermiso
            }
        @unknown default:
            throw ErrorGuardado.sinPermiso
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: imagen)
            }
        } catch {
            throw ErrorGuardado.fallo(error.localizedDescription)
        }
    }
}
