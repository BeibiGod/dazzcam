import SwiftUI

/// Editor para ponerle filtro a una foto que ya tenias en el carrete.
/// Elige la camara, mira el resultado y guarda una copia.
struct PhotoEditorView: View {
    let imagen: UIImage
    let proporcion: Proporcion
    let sello: SelloFecha
    var alGuardar: (UIImage, FilterPreset) -> Void

    @StateObject private var miniaturas = FilterThumbnails()
    @State private var preset: FilterPreset
    @State private var vista: UIImage?
    @State private var calculando = false
    @State private var guardando = false
    @State private var error: String?
    @State private var token = 0

    @Environment(\.dismiss) private var cerrar

    init(
        imagen: UIImage,
        preset: FilterPreset,
        proporcion: Proporcion,
        sello: SelloFecha,
        alGuardar: @escaping (UIImage, FilterPreset) -> Void
    ) {
        self.imagen = imagen
        self.proporcion = proporcion
        self.sello = sello
        self.alGuardar = alGuardar
        _preset = State(initialValue: preset)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("PONER FILTRO")
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
                    if let vista = vista {
                        Image(uiImage: vista)
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 10)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }

                    if calculando, vista != nil {
                        ProgressView()
                            .tint(.white)
                            .padding(10)
                            .background(.black.opacity(0.5), in: Circle())
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
                .disabled(guardando || vista == nil)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .task {
            miniaturas.generar(desde: imagen)
            recalcular()
        }
        .onChange(of: preset) { _, _ in
            recalcular()
        }
    }

    // MARK: - Procesar

    private func recalcular() {
        let base = imagen
        let elegido = preset
        let relacion = proporcion.relacion
        let marca = sello

        token += 1
        let mio = token
        calculando = true

        DispatchQueue.global(qos: .userInitiated).async {
            var salida = FilterEngine.aplicar(elegido, a: base)
            if let relacion = relacion {
                salida = FilterEngine.recortar(salida, relacion: relacion)
            }
            salida = SelloFecha.estampar(salida, modo: marca)

            DispatchQueue.main.async {
                guard mio == token else { return }
                vista = salida
                calculando = false
            }
        }
    }

    private func guardar() {
        guard let vista = vista else { return }
        guardando = true
        error = nil

        Task {
            do {
                try await PhotoLibrarySaver.guardar(vista)
                alGuardar(vista, preset)
                cerrar()
            } catch {
                self.error = "No se pudo guardar: \(error.localizedDescription)"
            }
            guardando = false
        }
    }
}

struct PhotoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoEditorView(
            imagen: UIImage(systemName: "photo")!,
            preset: .kodakGold,
            proporcion: .completa,
            sello: .fechaHora,
            alGuardar: { _, _ in }
        )
    }
}
