import SwiftUI

/// Control del look: que tan fuerte se ve el filtro, cuanta pelicula sucia
/// (puntitos y grano) y cuanta fuga de luz. Se aplica a todas las camaras.
struct AjustesLookView: View {
    @Binding var controles: ControlesLook
    let preset: FilterPreset

    @Environment(\.dismiss) private var cerrar

    private var sugerido: AjusteFoto {
        FilterEngine.ajuste(preset)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Muevelo y mira el cambio en el visor.")
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
                    titulo: "PUNTITOS",
                    detalle: "Polvo y rayones de pelicula",
                    valor: opcional(\.polvo, sugerido: sugerido.polvo),
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
            preset: .disposable
        )
    }
}