import SwiftUI

/// Flujo CAMERA→CIRCLES: camara real con visor en vivo + disparo grande
/// circular. Captura 1a, luego 2a, muestra ambas y pasa al editor Circles.
struct CirclesCameraView: View {
    var preset: FilterPreset = .original
    var controles: ControlesLook = ControlesLook()
    var sello: SelloFecha = .apagado
    var onDone: ([UIImage]) -> Void

    @StateObject private var camara = CameraSession()
    @StateObject private var foto = PhotoCapture()

    @State private var capturadas: [UIImage] = []
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camara.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button { cerrar() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(capturadas.isEmpty ? "FOTO 1 DE 2" : "FOTO 2 DE 2")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.black.opacity(0.5), in: Capsule())
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 16).padding(.top, 8)

                Spacer()

                // referencia de ambas antes de continuar
                if !capturadas.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(Array(capturadas.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.6), lineWidth: 1))
                        }
                    }
                    .padding(.bottom, 8)
                }

                // disparo grande circular
                Button {
                    foto.disparar()
                } label: {
                    ZStack {
                        Circle().fill(.white.opacity(0.12)).frame(width: 92, height: 92)
                        Circle().strokeBorder(.white, lineWidth: 4).frame(width: 76, height: 76)
                        Circle().fill(.white).frame(width: 62, height: 62)
                    }
                    .frame(width: 92, height: 92)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(foto.capturando || capturadas.count >= 2)
                .padding(.bottom, 28)
            }
        }
        .task {
            _ = foto.conectar(a: camara.session)
            await camara.arrancar()
        }
        .onDisappear { camara.detener() }
        .onChange(of: foto.capturas) { _, _ in
            guard let img = foto.ultimaFoto, capturadas.count < 2 else { return }
            capturadas.append(img)
            if capturadas.count == 2 {
                let imgs = capturadas
                Task { @MainActor in
                    onDone(imgs)   // pasa automaticamente al editor Circles
                }
            }
        }
    }
}
