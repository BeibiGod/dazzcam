import SwiftUI

/// Fila chiquita que muestra la fecha tal como va a quedar quemada en la
/// foto o en el video, con la tipografia y el color de la camara elegida.
/// Al tocar la etiqueta de la derecha se cambia el sello sin abrir nada.
struct FilaFecha: View {
    @Binding var sello: SelloFecha
    let estilo: EstiloFecha
    var fecha: Date = Date()
    /// Rotulo que la camara traia quemado, como NIGHTSHOT.
    var rotulo: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text("FECHA")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))

            if sello.encendido || rotulo != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let rotulo = rotulo {
                        Text("\"\(rotulo)\"")
                            .font(.custom(estilo.fuente(11).fontName, fixedSize: 11))
                            .tracking(estilo.interletra * 11)
                            .foregroundStyle(Color(uiColor: estilo.color).opacity(0.85))
                    }

                    if sello.encendido {
                        Text(SelloFecha.texto(sello, fecha: fecha))
                            .font(.custom(estilo.fuente(17).fontName, fixedSize: 17))
                            .tracking(estilo.interletra * 17)
                            .foregroundStyle(Color(uiColor: estilo.color))
                            .shadow(color: .black.opacity(0.6), radius: 1, x: 1, y: 1)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                }
            } else {
                Text("Sin fecha")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    sello = sello.siguiente
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8, weight: .bold))

                    Text(sello.etiqueta)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
