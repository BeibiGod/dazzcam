import SwiftUI

/// Pantalla de camara. Paso 3: preview en vivo + boton de disparo
/// que captura una foto y la muestra encima.
struct CameraView: View {
    @StateObject private var camara = CameraSession()
    @StateObject private var foto = PhotoCapture()

    @State private var fotoConectada = false
    @State private var mostrarCaptura = false
    @State private var aviso: String?

    private var versionTexto: String {
        "paso 4 · v0.4"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camara.session)
                .ignoresSafeArea()

            if mostrarCaptura, let imagen = foto.ultimaFoto {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .onTapGesture {
                        mostrarCaptura = false
                    }
                    .transition(.opacity)
            }

            VStack {
                HStack {
                    Text(versionTexto)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.45), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if let aviso = aviso {
                    Text(aviso)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .padding(.bottom, 10)
                }

                if let error = foto.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.75), in: Capsule())
                        .padding(.bottom, 12)
                }

                HStack(spacing: 20) {
                    Text(camara.estado.descripcion)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))

                    Button {
                        foto.disparar()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)

                            Circle()
                                .fill(foto.capturando ? Color.gray : Color.white)
                                .frame(width: 58, height: 58)
                        }
                    }
                    .disabled(camara.estado != .listo || foto.capturando)

                    Button {
                        mostrarCaptura = true
                    } label: {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .disabled(foto.ultimaFoto == nil)
                }
                .padding(.bottom, 34)
            }
        }
        .task {
            if !fotoConectada {
                fotoConectada = foto.conectar(a: camara.session)
            }
            await camara.arrancar()
        }
        .onChange(of: foto.capturas) { _, _ in
            guard let imagen = foto.ultimaFoto else { return }
            mostrarCaptura = true
            Task {
                do {
                    try await PhotoLibrarySaver.guardar(imagen)
                    aviso = "Guardada en tu fototeca"
                } catch {
                    aviso = "No se pudo guardar: \(error.localizedDescription)"
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                aviso = nil
            }
        }
        .onDisappear {
            camara.detener()
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
