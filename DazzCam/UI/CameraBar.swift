import SwiftUI

/// Barra inferior estilo DazzCam: tira de camaritas con muestra,
/// boton de disparo y accesos.
struct CameraBar: View {
    @Binding var seleccionado: FilterPreset
    let muestras: [FilterPreset: UIImage]
    let capturando: Bool

    var alDisparar: () -> Void
    var alAbrirGaleria: () -> Void
    var alAbrirTodas: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(seleccionado.nombre.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.black.opacity(0.45), in: Capsule())

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
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 64)

            HStack {
                Button(action: alAbrirGaleria) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
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

                        Circle()
                            .fill(capturando ? Color.gray : Color.white)
                            .frame(width: 64, height: 64)
                    }
                }
                .buttonStyle(.plain)
                .disabled(capturando)

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
            .padding(.horizontal, 26)
        }
    }
}
