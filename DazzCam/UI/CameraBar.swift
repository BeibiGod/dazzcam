import SwiftUI

/// Barra inferior estilo DazzCam: tira de camaritas con muestra, boton de
/// disparo al centro, FOTO a la izquierda, VIDEO a la derecha y la IA justo
/// antes del video.
struct CameraBar: View {
    @Binding var seleccionado: FilterPreset
    @Binding var modo: ModoCaptura
    let muestras: [FilterPreset: UIImage]
    let capturando: Bool
    let grabando: Bool
    let procesando: Bool
    let segundos: Int
    let analizando: Bool
    let favoritas: Set<FilterPreset>
    /// true cuando la IA ya dejo el encuadre listo: el disparador se pone
    /// amarillo, igual que en Framed.
    var listo: Bool = false

    var alDisparar: () -> Void
    var alIA: () -> Void
    var alFavorita: (FilterPreset) -> Void
    var alImportar: (() -> Void)?
    var alSelector: (() -> Void)?

    private var camaras: [FilterPreset] {
        FilterPreset.ordenadas(FilterPreset.allCases, favoritas: favoritas)
    }

    private var tiempoTexto: String {
        let minutos = segundos / 60
        let resto = segundos % 60
        return String(format: "%d:%02d", minutos, resto)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(seleccionado.nombre.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.5), in: Capsule())

                if grabando {
                    Text("● \(tiempoTexto)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red, in: Capsule())
                } else if procesando {
                    Text("GUARDANDO...")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.yellow, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(camaras) { preset in
                            Button {
                                seleccionado = preset
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.12))

                                    if let muestra = muestras[preset] {
                                        Image(uiImage: muestra)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "camera.aperture")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(
                                        seleccionado == preset ? Color.white : Color.white.opacity(0.22),
                                        lineWidth: seleccionado == preset ? 3 : 1
                                    )
                                )
                                .overlay(alignment: .topTrailing) {
                                    if favoritas.contains(preset) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.black)
                                            .frame(width: 16, height: 16)
                                            .background(Color.yellow, in: Circle())
                                            .offset(x: 1, y: -1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    alFavorita(preset)
                                } label: {
                                    Label(
                                        LocalizedStringKey(
                                            favoritas.contains(preset)
                                                ? "Quitar de favoritas"
                                                : "Marcar favorita"
                                        ),
                                        systemImage: favoritas.contains(preset)
                                            ? "star.slash"
                                            : "star"
                                    )
                                }
                            }
                            .id(preset)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 64)
                .onChange(of: seleccionado) { _, nuevo in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(nuevo, anchor: .center)
                    }
                }
            }

            // FOTO abajo a la izquierda, la IA a su lado, VIDEO a la
            // derecha y el selector de camaras al extremo de la derecha.
            // El disparador queda centrado de verdad.
            ZStack {
                disparador

                HStack(spacing: 8) {
                    botonImportar

                    botonModo(.foto)

                    Spacer(minLength: 0)

                    botonIA

                    botonModo(.video)
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Disparador

    private var disparador: some View {
        Button(action: alDisparar) {
            ZStack {
                // Halo suave: da area de toque y separa el boton del fondo.
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 92, height: 92)

                Circle()
                    .strokeBorder(
                        listo ? Color.yellow : Color.white,
                        lineWidth: listo ? 5 : 4
                    )
                    .frame(width: 76, height: 76)
                    .shadow(
                        color: listo ? Color.yellow.opacity(0.65) : .black.opacity(0.25),
                        radius: listo ? 12 : 4
                    )

                if grabando {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                        .shadow(color: .red.opacity(0.35), radius: 6)
                } else {
                    Circle()
                        .fill(
                            capturando || procesando
                                ? Color.gray
                                : Color.white
                        )
                        .frame(width: 62, height: 62)
                        .overlay(
                            Circle().strokeBorder(
                                Color.black.opacity(0.08),
                                lineWidth: 1
                            )
                        )
                }
            }
            .frame(width: 92, height: 92)
            .contentShape(Circle())
            .scaleEffect(capturando || procesando ? 0.96 : 1)
            .animation(.easeOut(duration: 0.18), value: listo)
        }
        .buttonStyle(.plain)
        .disabled(capturando || procesando)
        .accessibilityLabel(grabando ? "Detener" : "Disparar")
    }

    // MARK: - Modos y IA

    private func botonModo(_ opcion: ModoCaptura) -> some View {
        let activo = modo == opcion

        return Button {
            guard !grabando else { return }
            modo = opcion
        } label: {
            HStack(spacing: 5) {
                Image(systemName: opcion == .foto ? "camera.fill" : "video.fill")
                    .font(.system(size: 11, weight: .bold))

                Text(LocalizedStringKey(opcion.rawValue))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(activo ? Color.black : Color.white.opacity(0.85))
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(
                activo ? Color.white : Color.black.opacity(0.5),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    Color.white.opacity(activo ? 0 : 0.22),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .opacity(grabando && !activo ? 0.45 : 1)
    }

    private var botonIA: some View {
        Button(action: alIA) {
            HStack(spacing: 5) {
                if analizando {
                    ProgressView()
                        .scaleEffect(0.55)
                        .tint(.black)
                        .frame(width: 13, height: 13)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text("IA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(red: 1.0, green: 0.30, blue: 0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var botonImportar: some View {
        Button {
            alImportar?()
        } label: {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.45), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
