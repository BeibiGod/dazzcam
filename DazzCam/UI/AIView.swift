import SwiftUI

/// Hoja con el resultado del analisis: puntaje, consejos y camara sugerida.
struct AIView: View {
    let analisis: Analisis
    var alElegirCamara: (FilterPreset) -> Void
    var alVerTodas: () -> Void

    @Environment(\.dismiss) private var cerrar

    private var colorPuntaje: Color {
        switch analisis.puntaje {
        case 88...100: return Color(red: 0.35, green: 0.9, blue: 0.5)
        case 80..<88: return Color(red: 0.75, green: 0.95, blue: 0.35)
        default: return Color(red: 1.0, green: 0.82, blue: 0.3)
        }
    }

    private func medida(_ titulo: String, _ valor: String) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Text(titulo)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(analisis.puntaje)")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundStyle(colorPuntaje)

                        Text("/ 100")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))

                        Spacer()
                    }

                    Text(analisis.resumen)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            medida("LUZ", "\(analisis.luz)%")
                            medida("CONTRASTE", "\(analisis.contraste)%")
                            medida("COLOR", "\(analisis.color)%")
                            medida("CARAS", "\(analisis.caras)")
                            medida("HORIZONTE", "\(analisis.horizonte)°")
                        }
                        .padding(.vertical, 2)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(analisis.consejos.enumerated()), id: \.offset) { _, consejo in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "camera.filters")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(red: 1.0, green: 0.30, blue: 0.55))
                                    .padding(.top, 3)

                                Text(consejo)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if !analisis.etiquetas.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LO QUE VEO")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))

                            Text(analisis.etiquetas.joined(separator: "  ·  "))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("CAMARAS QUE LE QUEDAN")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))

                        ForEach(Array(analisis.sugerencias.enumerated()), id: \.offset) { indice, preset in
                            Button {
                                alElegirCamara(preset)
                            } label: {
                                HStack {
                                    Text(preset.nombre)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    Spacer()
                                    if indice == 0 {
                                        Text("LA QUE MAS PEGA")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(colorPuntaje, in: Capsule())
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            alVerTodas()
                        } label: {
                            Text("VER LAS \(FilterPreset.cantidadCamaras) CAMARAS")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Mira toda la escena: luz, contraste, color, caras y horizonte, y elige las camaras que mejor le quedan. No importa si hay mucha o poca luz: siempre busca lo mas aesthetic. Todo pasa dentro de tu iPhone; no se sube nada a internet.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea())
            .navigationTitle("Analisis aesthetic")
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
