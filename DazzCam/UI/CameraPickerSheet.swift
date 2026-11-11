import SwiftUI

/// Hoja con todas las camaras, agrupadas, cada una con su muestra.
struct CameraPickerSheet: View {
    @Binding var seleccionado: FilterPreset
    let muestras: [FilterPreset: UIImage]

    @Environment(\.dismiss) private var cerrar

    private let columnas = [GridItem(.adaptive(minimum: 88), spacing: 14)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(FilterCategoria.allCases) { categoria in
                        let items = FilterPreset.allCases.filter { $0.categoria == categoria }

                        if !items.isEmpty {
                            Text(categoria.titulo)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.65))
                                .padding(.horizontal, 20)
                                .padding(.top, 18)

                            LazyVGrid(columns: columnas, spacing: 16) {
                                ForEach(items) { preset in
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

                                            Text(preset.nombre)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.85))
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        }
                    }
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
}
