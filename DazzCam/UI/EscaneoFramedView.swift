import SwiftUI

/// Hoja de resultado del escaneo estilo Framed: luz, contraste, color,
/// horizonte y caras de la escena, más el sujeto que conviene dejar.
struct EscaneoFramedView: View {
    let escaneo: EscaneoFramed.Escaneo
    var alAplicar: () -> Void

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
                        Text("\(escaneo.puntaje)")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.3))

                        Text("/ 100")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))

                        Spacer()
                    }

                    Text(escaneo.resumen)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            medida("LUZ", "\(escaneo.luz)%")
                            medida("CONTRASTE", "\(escaneo.contraste)%")
                            medida("COLOR", "\(escaneo.color)%")
                            medida("CARAS", "\(escaneo.caras)")
                            medida("HORIZONTE", "\(escaneo.horizonte)°")
                        }
                        .padding(.vertical, 2)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("SUJETO")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))

                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.82, blue: 0.3))
                                .frame(width: 5, height: 5)

                            Text(escaneo.etiqueta)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)

                            Spacer()

                            let w = Int((escaneo.sujeto.width * 100).rounded())
                            let h = Int((escaneo.sujeto.height * 100).rounded())
                            Text("\(w)% × \(h)%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    if let guia = escaneo.guia, !guia.instruccion.isEmpty {
                        Text(guia.instruccion)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    if !escaneo.consejos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CONSEJOS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))

                            ForEach(Array(escaneo.consejos.enumerated()), id: \.offset) { _, consejo in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(red: 1.0, green: 0.30, blue: 0.55))
                                        .padding(.top, 3)

                                    Text(consejo)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    Text(L("Escaneo local: nada de esta escena sale a internet."))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea())
            .navigationTitle("Escaneo Framed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Aplicar")) {
                        alAplicar()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
