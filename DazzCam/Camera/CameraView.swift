import SwiftUI

/// Pantalla de camara. Paso 5: preview + disparo + guardado + filtros.
struct CameraView: View {
    @StateObject private var camara = CameraSession()
    @StateObject private var foto = PhotoCapture()

    @State private var fotoConectada = false
    @State private var mostrarCaptura = false
    @State private var aviso: String?
    @State private var preset: FilterPreset = .original
    @State private var fotoFiltrada: UIImage?

    private let versionTexto = "paso 5 · v0.5"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camara.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
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

                if let texto = aviso {
                    Text(texto)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(.bottom, 10)
                }

                if let error = foto.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.75), in: Capsule())
                        .padding(.bottom, 10)
                }

                carruselFiltros

                HStack(spacing: 20) {
                    Text(camara.estado.descripcion)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 70)

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
                    .disabled(fotoFiltrada == nil)
                    .frame(width: 70)
                }
                .padding(.bottom, 34)
            }

            if mostrarCaptura, let imagen = fotoFiltrada {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .onTapGesture {
                        mostrarCaptura = false
                    }
                    .transition(.opacity)
            }
        }
        .task {
            if !fotoConectada {
                fotoConectada = foto.conectar(a: camara.session)
            }
            await camara.arrancar()
        }
        .onDisappear {
            camara.detener()
        }
        .onChange(of: foto.capturas) { _, _ in
            guard let base = foto.ultimaFoto else { return }
            let procesada = FilterEngine.aplicar(preset, a: base)
            fotoFiltrada = procesada
            mostrarCaptura = true

            Task {
                do {
                    try await PhotoLibrarySaver.guardar(procesada)
                    aviso = "Guardada en tu fototeca"
                } catch {
                    aviso = "No se pudo guardar: \(error.localizedDescription)"
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                aviso = nil
            }
        }
    }

    private var carruselFiltros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterPreset.allCases) { item in
                    Button {
                        preset = item
                        aplicarFiltroAUltima()
                    } label: {
                        Text(item.rawValue)
                            .font(.caption)
                            .fontWeight(preset == item ? .bold : .regular)
                            .foregroundStyle(preset == item ? Color.black : Color.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                preset == item ? Color.white : Color.white.opacity(0.18),
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
    }

    private func aplicarFiltroAUltima() {
        guard let base = foto.ultimaFoto else { return }
        fotoFiltrada = FilterEngine.aplicar(preset, a: base)
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
