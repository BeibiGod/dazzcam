import AVKit
import SwiftUI
import UIKit

/// Editor para ponerle filtro a un video que ya tenias en el carrete.
/// Se ve el video con el look puesto y se guarda una copia con sonido.
struct VideoEditorView: View {
    let url: URL
    let controles: ControlesLook
    let sello: SelloFecha
    let fecha: Date
    var alGuardar: (FilterPreset) -> Void

    @StateObject private var miniaturas = FilterThumbnails()
    @State private var preset: FilterPreset
    @State private var intensidad: CGFloat
    @State private var reproductor: AVPlayer?
    @State private var guardando = false
    @State private var error: String?
    @State private var tokenReproductor = 0
    @State private var semilla = UInt64.random(in: 1...UInt64.max)

    @Environment(\.dismiss) private var cerrar

    init(
        url: URL,
        preset: FilterPreset,
        controles: ControlesLook = ControlesLook(),
        sello: SelloFecha = .apagado,
        fecha: Date = Date(),
        alGuardar: @escaping (FilterPreset) -> Void
    ) {
        self.url = url
        self.controles = controles
        self.sello = sello
        self.fecha = fecha
        self.alGuardar = alGuardar
        _preset = State(initialValue: preset)
        _intensidad = State(initialValue: controles.intensidad)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("PONER FILTRO AL VIDEO")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Button {
                        cerrar()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                ZStack {
                    if let reproductor = reproductor {
                        VideoPlayer(player: reproductor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 10)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(maxHeight: .infinity)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FilterPreset.allCases) { opcion in
                                Button {
                                    preset = opcion
                                } label: {
                                    ZStack {
                                        Circle().fill(Color.white.opacity(0.12))

                                        if let muestra = miniaturas.muestras[opcion] {
                                            Image(uiImage: muestra)
                                                .resizable()
                                                .scaledToFill()
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().strokeBorder(
                                            preset == opcion ? Color.white : Color.white.opacity(0.2),
                                            lineWidth: preset == opcion ? 3 : 1
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(opcion)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .frame(height: 56)
                    .onChange(of: preset) { _, nuevo in
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo(nuevo, anchor: .center)
                        }
                    }
                }

                Text(preset.nombre.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 10) {
                    Text("INTENSIDAD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    Slider(value: $intensidad, in: 0...1)
                        .tint(.white)

                    Text("\(Int((intensidad * 100).rounded()))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.horizontal, 18)

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.7), in: Capsule())
                }

                Button {
                    guardar()
                } label: {
                    HStack(spacing: 8) {
                        if guardando {
                            ProgressView()
                                .tint(.black)
                        }

                        Text(guardando ? "GUARDANDO" : "GUARDAR COPIA")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(guardando)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .task {
            if let cuadro = await VideoBaker.cuadro(de: url) {
                miniaturas.generar(desde: cuadro)
            }
            prepararReproductor()
        }
        .onChange(of: preset) { _, _ in
            prepararReproductor()
        }
        .onChange(of: intensidad) { _, _ in
            prepararReproductor()
        }
        .onDisappear {
            reproductor?.pause()
        }
    }

    // MARK: - Reproductor con el filtro puesto

    private func prepararReproductor() {
        tokenReproductor += 1
        let mio = tokenReproductor

        reproductor?.pause()

        let look = preset
        var ajustes = controles
        ajustes.intensidad = intensidad

        let archivo = url
        let marca = sello
        let cuando = fecha
        let azar = semilla

        // Espera a que el dedo deje de moverse antes de rehacer el video.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard mio == tokenReproductor else { return }

            let asset = AVURLAsset(url: archivo)
            let item = AVPlayerItem(asset: asset)
            item.videoComposition = VideoBaker.composicion(
                asset,
                preset: look,
                controles: ajustes,
                sello: marca,
                fecha: cuando,
                semilla: azar
            )

            reproductor = AVPlayer(playerItem: item)
        }
    }

    // MARK: - Guardar

    private func guardar() {
        guardando = true
        error = nil
        reproductor?.pause()

        let archivo = url
        let look = preset
        var ajustes = controles
        ajustes.intensidad = intensidad
        let marca = sello
        let cuando = fecha
        let azar = semilla

        Task {
            do {
                let salida = try await VideoBaker.exportar(
                    archivo,
                    preset: look,
                    controles: ajustes,
                    sello: marca,
                    fecha: cuando,
                    semilla: azar
                )
                try await PhotoLibrarySaver.guardarVideo(salida)
                try? FileManager.default.removeItem(at: salida)

                alGuardar(look)
                cerrar()
            } catch {
                self.error = "No se pudo guardar: \(error.localizedDescription)"
            }
            guardando = false
        }
    }
}

struct VideoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        VideoEditorView(
            url: URL(fileURLWithPath: "/tmp/video.mp4"),
            preset: .kodakGold,
            alGuardar: { _ in }
        )
    }
}