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

    // Zoom para revisar la foto mientras la editas. No cambia lo que se guarda.
    @State private var zoom: CGFloat = 1
    @State private var zoomGuardado: CGFloat = 1
    @State private var desplazamiento: CGSize = .zero
    @State private var desplazamientoGuardado: CGSize = .zero

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

                GeometryReader { geo in
                    ZStack {
                        if let vista = vista {
                            let tamano = tamanoAjustado(vista, en: geo.size)

                            Image(uiImage: vista)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(zoom)
                                .offset(desplazamiento)
                                .contentShape(Rectangle())
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { valor in
                                                zoom = min(max(zoomGuardado * valor, 1), 5)
                                            }
                                            .onEnded { _ in
                                                zoomGuardado = zoom
                                                if zoom <= 1.01 {
                                                    restablecerZoom()
                                                } else {
                                                    limitarDesplazamiento(
                                                        tamano: tamano,
                                                        caja: geo.size
                                                    )
                                                }
                                            },
                                        DragGesture()
                                            .onChanged { valor in
                                                guard zoom > 1.01 else { return }
                                                desplazamiento = CGSize(
                                                    width: desplazamientoGuardado.width
                                                        + valor.translation.width,
                                                    height: desplazamientoGuardado.height
                                                        + valor.translation.height
                                                )
                                            }
                                            .onEnded { _ in
                                                desplazamientoGuardado = desplazamiento
                                                limitarDesplazamiento(
                                                    tamano: tamano,
                                                    caja: geo.size
                                                )
                                            }
                                    )
                                )
                                .onTapGesture(count: 2) {
                                    if zoom > 1.01 {
                                        restablecerZoom()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            zoom = 2.5
                                            zoomGuardado = 2.5
                                        }
                                    }
                                }
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

                        // Chincheta del zoom: se toca para volver a 1x.
                        if vista != nil {
                            VStack {
                                HStack {
                                    Spacer()

                                    Button {
                                        restablecerZoom()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 9, weight: .bold))
                                            Text(String(format: "%.1fx", zoom))
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .monospacedDigit()
                                        }
                                        .foregroundStyle(zoom > 1.01 ? Color.black : Color.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(
                                            zoom > 1.01 ? Color.white : Color.black.opacity(0.35),
                                            in: Capsule()
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Spacer()
                            }
                            .padding(10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .padding(.horizontal, 10)
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
                        sello = nuevo.selloDeFabrica
                        controles.estiloFecha = nuevo.estiloDeFecha
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo(nuevo, anchor: .center)
                        }
                    }
                }

                Text(preset.nombre.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                FilaFecha(
                    sello: $sello,
                    estilo: controles.estiloFecha,
                    rotulo: preset.rotulo
                )
                    .padding(.horizontal, 18)

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

    // MARK: - Zoom

    /// Tamano con el que la foto entra en la caja, respetando su proporcion.
    private func tamanoAjustado(_ imagen: UIImage, en caja: CGSize) -> CGSize {
        guard caja.width > 0, caja.height > 0, imagen.size.height > 0 else { return caja }

        let relacion = imagen.size.width / imagen.size.height
        let relacionCaja = caja.width / caja.height

        if relacion > relacionCaja {
            return CGSize(width: caja.width, height: caja.width / relacion)
        }
        return CGSize(width: caja.height * relacion, height: caja.height)
    }

    /// Que no se pueda arrastrar la foto fuera de la pantalla.
    private func limitarDesplazamiento(tamano: CGSize, caja: CGSize) {
        let maxX = max((tamano.width * zoom - caja.width) / 2, 0)
        let maxY = max((tamano.height * zoom - caja.height) / 2, 0)

        desplazamiento = CGSize(
            width: min(max(desplazamiento.width, -maxX), maxX),
            height: min(max(desplazamiento.height, -maxY), maxY)
        )
        desplazamientoGuardado = desplazamiento
    }

    private func restablecerZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoom = 1
            zoomGuardado = 1
            desplazamiento = .zero
            desplazamientoGuardado = .zero
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
                    estilo: ajustes.estiloFecha,
                    rotulo: elegido.rotulo
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
