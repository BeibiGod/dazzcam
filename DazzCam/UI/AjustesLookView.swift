import SwiftUI

/// Control del look: que tan fuerte se ve el filtro, cuantos rayones, fuga
/// de luz, grano y que fecha se quema. Se aplica a todas las camaras.
struct AjustesLookView: View {
    @Binding var controles: ControlesLook
    @Binding var sello: SelloFecha
    let preset: FilterPreset

    @Environment(\.dismiss) private var cerrar

    private var sugerido: AjusteFoto {
        FilterEngine.ajuste(preset)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Muevelo y mira el cambio.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))

                fila(
                    titulo: "INTENSIDAD",
                    detalle: "Que tanto se ve el filtro",
                    valor: $controles.intensidad,
                    rango: 0...1,
                    maximo: 1
                )

                fila(
                    titulo: "RAYONES",
                    detalle: "Rayones finos de pelicula vieja",
                    valor: opcional(\.rayones, sugerido: sugerido.rayones),
                    rango: 0...1,
                    maximo: 1
                )

                fila(
                    titulo: "FUGAS DE LUZ",
                    detalle: "Luz que se cuela por una esquina",
                    valor: opcional(\.fuga, sugerido: sugerido.fuga),
                    rango: 0...1,
                    maximo: 1
                )

                fila(
                    titulo: "GRANO",
                    detalle: "Textura de pelicula",
                    valor: opcional(\.grano, sugerido: sugerido.grano),
                    rango: 0...0.35,
                    maximo: 0.35
                )

                filaFecha

                HStack {
                    Button {
                        controles = ControlesLook()
                    } label: {
                        Text("AUTOMATICO")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(controles.automatico)

                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("EL LOOK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { cerrar() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    /// Fila para elegir la fecha que se quema en la foto o el video.
    private var filaFecha: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("FECHA")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Menu {
                    ForEach(SelloFecha.allCases) { modo in
                        Button {
                            sello = modo
                        } label: {
                            if sello == modo {
                                Label(modo.tituloMenu, systemImage: "checkmark")
                            } else {
                                Text(modo.tituloMenu)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(sello.tituloMenu)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
            }

            Text("La hora sale de tu iPhone")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func opcional(
        _ clave: WritableKeyPath<ControlesLook, CGFloat?>,
        sugerido: CGFloat
    ) -> Binding<CGFloat> {
        Binding(
            get: { controles[keyPath: clave] ?? sugerido },
            set: { controles[keyPath: clave] = $0 }
        )
    }

    private func fila(
        titulo: String,
        detalle: String,
        valor: Binding<CGFloat>,
        rango: ClosedRange<CGFloat>,
        maximo: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int((valor.wrappedValue / maximo * 100).rounded()))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
            }

            Slider(value: valor, in: rango)
                .tint(.white)

            Text(detalle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

struct AjustesLookView_Previews: PreviewProvider {
    static var previews: some View {
        AjustesLookView(
            controles: .constant(ControlesLook()),
            sello: .constant(.dazz),
            preset: .disposable
        )
    }
}