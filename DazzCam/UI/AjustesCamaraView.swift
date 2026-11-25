import SwiftUI

/// Ajustes generales de la camara: idioma.
/// Se abre con el engranaje de arriba a la derecha.
struct AjustesCamaraView: View {
    @Binding var idioma: Idioma

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
        AjustesCamaraView(idioma: .constant(.es))
    }
}
