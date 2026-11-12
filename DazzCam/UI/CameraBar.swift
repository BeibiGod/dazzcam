import SwiftUI

/// Barra inferior estilo DazzCam: tira de camaritas con muestra,
/// boton de disparo y accesos.
struct CameraBar: View {
    @Binding var seleccionado: FilterPreset
    let muestras: [FilterPreset: UIImage]
    let capturando: Bool
    let grabando: Bool
    let procesando: Bool
    let segundos: Int

    var alDisparar: () -> Void
    var alImportar: () -> Void
    var alAbrirTodas: () -> Void

    private var tiempoTexto: String {
        let minutos = segundos / 60
        let resto = segundos % 60
        return String(format: "%d:%02d", minutos, resto)
    }

    var body: some View {
        VStack(spacing: 12) {
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
                    HStack(spacing: 12) {
                        ForEach(FilterPreset.allCases) { preset in
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
                            }
                            .buttonStyle(.plain)
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

            HStack {
                Button(action: alImportar) {
                    VStack(spacing: 3) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18))
                        Text("FOTOS")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: alDisparar) {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 78, height: 78)

                        if grabando {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.red)
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(capturando || procesando ? Color.gray : Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(capturando || procesando)

                Spacer()

                Button(action: alAbrirTodas) {
                    VStack(spacing: 3) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 18))
                        Text("TODAS")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity)
    }
}
