import SwiftUI

/// Ajustes generales de la camara: idioma, proporcion y cuadricula.
/// Se abre con el engranaje de arriba a la derecha.
struct AjustesCamaraView: View {
    @Binding var idioma: Idioma
    @Binding var proporcion: Proporcion
    @Binding var mostrarCuadricula: Bool

    @Environment(\.dismiss) private var cerrar


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    seccion(
                        titulo: "IDIOMA",
                        detalle: "Toda la app cambia al instante"
                    ) {
                        HStack(spacing: 8) {
                            ForEach(Idioma.allCases) { opcion in
                                boton(
                                    titulo: opcion.nombre,
                                    activo: idioma == opcion
                                ) {
                                    idioma = opcion
                                }
                            }
                        }
                    }

                    seccion(
                        titulo: "PROPORCION",
                        detalle: "16:9 es la de cine; 4:3 usa todo el sensor"
                    ) {
                        HStack(spacing: 8) {
                            ForEach(Proporcion.allCases, id: \.self) { opcion in
                                boton(
                                    titulo: opcion.etiqueta,
                                    activo: proporcion == opcion
                                ) {
                                    proporcion = opcion
                                }
                            }
                        }
                    }

                    seccion(
                        titulo: "CUADRICULA",
                        detalle: "Lineas de tercios y nivel para no torcer la foto"
                    ) {
                        Button {
                            mostrarCuadricula.toggle()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: mostrarCuadricula
                                    ? "square.grid.3x3.fill"
                                    : "square.grid.3x3")
                                    .font(.system(size: 15, weight: .semibold))

                                Text(LocalizedStringKey(
                                    mostrarCuadricula ? "ENCENDIDA" : "APAGADA"
                                ))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))

                                Spacer()

                                Capsule()
                                    .fill(mostrarCuadricula ? Color.yellow : Color.white.opacity(0.18))
                                    .frame(width: 44, height: 26)
                                    .overlay(alignment: mostrarCuadricula ? .trailing : .leading) {
                                        Circle()
                                            .fill(mostrarCuadricula ? Color.black : Color.white)
                                            .frame(width: 20, height: 20)
                                            .padding(3)
                                    }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(version)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("AJUSTES")
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

    private var version: String {
        let numero = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Beibi Cam v\(numero) · \(FilterPreset.cantidadCamaras) camaras"
    }

    private func seccion<Contenido: View>(
        titulo: String,
        detalle: String,
        @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(titulo))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            contenido()

            Text(LocalizedStringKey(detalle))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.38))
        }
    }

    private func boton(
        titulo: String,
        activo: Bool,
        accion: @escaping () -> Void
    ) -> some View {
        Button(action: accion) {
            Text(titulo)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(activo ? Color.black : Color.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    activo ? Color.yellow : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color.white.opacity(activo ? 0 : 0.14),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct AjustesCamaraView_Previews: PreviewProvider {
    static var previews: some View {
        AjustesCamaraView(
            idioma: .constant(.es),
            proporcion: .constant(.dieciseisNueve),
            mostrarCuadricula: .constant(true)
        )
    }
}
