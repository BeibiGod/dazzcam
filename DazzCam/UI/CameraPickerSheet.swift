import SwiftUI

/// Hoja con todas las camaras separadas en foto y video, ordenadas por año
/// de la mas vieja a la mas nueva. Las favoritas salen primero y se marcan
/// con la estrella de cada camara.
struct CameraPickerSheet: View {
    @Binding var seleccionado: FilterPreset
    @Binding var favoritas: Set<FilterPreset>
    let muestras: [FilterPreset: UIImage]

    @Environment(\.dismiss) private var cerrar

    private let columnas = [GridItem(.adaptive(minimum: 88), spacing: 14)]

    private var camarasFavoritas: [FilterPreset] {
        FilterPreset.allCases.filter { $0 != .original && favoritas.contains($0) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !camarasFavoritas.isEmpty {
                        encabezado("FAVORITAS", cuenta: camarasFavoritas.count)

                        LazyVGrid(columns: columnas, spacing: 16) {
                            ForEach(camarasFavoritas) { preset in
                                camara(preset)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    encabezado("SIN FILTRO")

                    LazyVGrid(columns: columnas, spacing: 16) {
                        camara(.original)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    ForEach(FilterPreset.porTipo) { grupo in
                        encabezado(grupo.titulo, cuenta: grupo.camaras.count)

                        LazyVGrid(columns: columnas, spacing: 16) {
                            ForEach(FilterPreset.ordenadas(
                                grupo.camaras,
                                favoritas: favoritas
                            )) { preset in
                                camara(preset)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    Text("Toca la estrella para que salga primero.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                }
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Camaras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { cerrar() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func encabezado(_ titulo: String, cuenta: Int? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(LocalizedStringKey(titulo))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))

            if let cuenta = cuenta {
                Text("\(cuenta)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.28))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private func camara(_ preset: FilterPreset) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                seleccionado = preset
                cerrar()
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.1))

                        if let muestra = muestras[preset] {
                            Image(uiImage: muestra)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                seleccionado == preset ? Color.white : Color.white.opacity(0.15),
                                lineWidth: seleccionado == preset ? 2 : 1
                            )
                    )
                    .overlay(alignment: .topLeading) {
                        if preset != .original {
                            Text("\(preset.anio)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(5)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        MiniCamara(familia: preset.familia)
                            .frame(width: 38, height: 27)
                            .padding(3)
                            .background(
                                Color.black.opacity(0.65),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                            .padding(5)
                    }

                    Text(preset.nombre)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(preset.marca)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            if preset != .original {
                Button {
                    if favoritas.contains(preset) {
                        favoritas.remove(preset)
                    } else {
                        favoritas.insert(preset)
                    }
                } label: {
                    Image(systemName: favoritas.contains(preset) ? "star.fill" : "star")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(favoritas.contains(preset) ? Color.black : Color.white)
                        .frame(width: 26, height: 26)
                        .background(
                            favoritas.contains(preset)
                                ? Color.yellow
                                : Color.black.opacity(0.55),
                            in: Circle()
                        )
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(5)
                .accessibilityLabel(
                    favoritas.contains(preset)
                        ? Text("Quitar de favoritas")
                        : Text("Marcar favorita")
                )
            }
        }
    }
}
