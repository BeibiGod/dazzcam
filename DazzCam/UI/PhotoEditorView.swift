import SwiftUI

/// Editor para ponerle filtro a una foto que ya tenias en el carrete.
/// Elige la camara, mira el resultado y guarda una copia.
struct PhotoEditorView: View {
    let imagen: UIImage
    let proporcion: Proporcion
    var alGuardar: (UIImage, FilterPreset) -> Void

    @StateObject private var miniaturas = FilterThumbnails()
    @State private var preset: FilterPreset
    @State private var sello: SelloFecha
    @State private var controles: ControlesLook
    @State private var mostrarAjustes = false
    @State private var vista: UIImage?
    @State private var calculando = false
    @State private var guardando = false
    @State private var error: String?
    @State private var token = 0
    @State private var semilla = UInt64.random(in: 1...UInt64.max)

    @Environment(\.dismiss) private var cerrar

    init(
        imagen: UIImage,
        preset: FilterPreset,
        proporcion: Proporcion,
        sello: SelloFecha,
        controles: ControlesLook = ControlesLook(),
        alGuardar: @escaping (UIImage, FilterPreset) -> Void
    ) {
        self.imagen = imagen
        self.proporcion = proporcion
        self.alGuardar = alGuardar
        _preset = State(initialValue: preset)
        _sello = State(initialValue: sello)
        _controles = State(initialValue: controles)
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

                HStack(spacing: 10) {
                    Text("INTENSIDAD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    Slider(value: $controles.intensidad, in: 0...1)
                        .tint(.white)

                    Text("\(Int((controles.intensidad * 100).rounded()))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.horizontal, 18)

                Button {
                    mostrarAjustes = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .semibold))
                        Text("RAYONES, FUGAS Y GRANO")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
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
        .onChange(of: controles) { _, _ in
            recalcular()
        }
        .onChange(of: sello) { _, _ in
            recalcular()
        }
        .sheet(isPresented: $mostrarAjustes) {
            AjustesLookView(controles: $controles, sello: $sello, preset: preset)
                .presentationDetents([.height(660)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(red: 0.06, green: 0.06, blue: 0.08))
        }
    }

    // MARK: - Procesar

    private func recalcular() {
        let base = imagen
        let elegido = preset
        let relacion = proporcion.relacion
        let marca = sello
        let ajustes = controles
        let azar = semilla

        token += 1
        let mio = token
        calculando = true

        // Espera a que el dedo deje de moverse antes de recalcular.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard mio == token else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                var salida = FilterEngine.aplicar(
                    elegido,
                    a: base,
                    controles: ajustes,
                    semilla: azar
                )
                if let relacion = relacion {
                    salida = FilterEngine.recortar(salida, relacion: relacion)
                }
                salida = SelloFecha.estampar(
                    salida,
                    modo: marca,
                    estilo: ajustes.estiloFecha
                )

                DispatchQueue.main.async {
                    guard mio == token else { return }
                    vista = salida
                    calculando = false
                }
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
                self.error = String(localized: "No se pudo guardar: \(error.localizedDescription)")
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
