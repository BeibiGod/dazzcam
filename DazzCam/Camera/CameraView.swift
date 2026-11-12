import SwiftUI
import Combine

/// Pantalla de camara estilo DazzCam: visor a pantalla completa,
/// tira de camaritas con muestra, disparo y selector completo.
struct CameraView: View {
    @StateObject private var camara = CameraSession()
    @StateObject private var foto = PhotoCapture()
    @StateObject private var vivo = LiveFilterPreview()
    @StateObject private var miniaturas = FilterThumbnails()

    @State private var preparado = false
    @State private var mostrarCaptura = false
    @State private var mostrarTodas = false
    @State private var aviso: String?
    @State private var preset: FilterPreset = .dazzClassic
    @State private var fotoFiltrada: UIImage?
    @State private var modoVivo = true

    private var versionTexto: String {
        "v0.8 · \(FilterPreset.cantidadCamaras) cam"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            visor

            VStack(spacing: 0) {
                cabecera
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

                CameraBar(
                    seleccionado: $preset,
                    muestras: miniaturas.muestras,
                    capturando: foto.capturando,
                    alDisparar: { foto.disparar() },
                    alAbrirGaleria: { mostrarCaptura = fotoFiltrada != nil },
                    alAbrirTodas: { mostrarTodas = true }
                )
                .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity)

            if mostrarCaptura, let imagen = fotoFiltrada {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .onTapGesture { mostrarCaptura = false }
                    .transition(.opacity)
            }
        }
        .task {
            if !preparado {
                preparado = true
                _ = foto.conectar(a: camara.session)
                _ = vivo.conectar(a: camara.session)
                vivo.preset = preset
            }
            await camara.arrancar()
        }
        .onDisappear {
            camara.detener()
        }
        .onChange(of: preset) { _, nuevo in
            vivo.preset = nuevo
            aplicarFiltroAUltima()
        }
        .onChange(of: foto.capturas) { _, _ in
            guard let base = foto.ultimaFoto else { return }

            // Si el video en vivo no dio cuadros, las muestras salen de la foto.
            if !miniaturas.lista {
                miniaturas.generar(desde: base)
            }

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
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                aviso = nil
            }
        }
        .onReceive(vivo.$imagen) { imagen in
            guard let imagen = imagen, !miniaturas.lista else { return }
            miniaturas.generar(desde: imagen)
        }
        .sheet(isPresented: $mostrarTodas) {
            CameraPickerSheet(seleccionado: $preset, muestras: miniaturas.muestras)
        }
    }

    // MARK: - Partes

    private var visor: some View {
        Group {
            if modoVivo, let imagenViva = vivo.imagen {
                Image(uiImage: imagenViva)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else {
                CameraPreviewView(session: camara.session)
                    .ignoresSafeArea()
            }
        }
    }

    private var cabecera: some View {
        HStack(spacing: 8) {
            Text(versionTexto)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.5), in: Capsule())

            Spacer(minLength: 6)

            if modoVivo {
                Text("\(vivo.cuadrosPorSegundo) FPS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        vivo.cuadrosPorSegundo >= 20 ? Color.green : Color.yellow,
                        in: Capsule()
                    )
            }

            Button {
                modoVivo.toggle()
            } label: {
                Text("EN VIVO")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(modoVivo ? Color.black : Color.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        modoVivo ? Color.white : Color.white.opacity(0.22),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
