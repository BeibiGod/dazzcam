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
            ScrollView {
                VStack(spacing: 16) {
                    vistaPreviaFecha

                    Text("Muevelo y mira el cambio.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))

                    fila(
                        titulo: "INTENSIDAD",
                        detalle: "Baja todo el look. Lo que muevas a mano se queda",
                        valor: $controles.intensidad,
                        rango: 0...1,
                        maximo: 1
                    )

                    filaAjuste(
                        titulo: "EXPOSICION",
                        detalle: "Aclara u oscurece toda la foto",
                        clave: \.exposicion
                    )

                    filaAjuste(
                        titulo: "CONTRASTE",
                        detalle: "Separa mas las luces de las sombras",
                        clave: \.contraste
                    )

                    filaAjuste(
                        titulo: "SATURACION",
                        detalle: "De gris apagado a color intenso",
                        clave: \.saturacion
                    )

                    filaAjuste(
                        titulo: "TEMPERATURA",
                        detalle: "Azul de noche a calido de tarde",
                        clave: \.temperatura
                    )

                    filaAjuste(
                        titulo: "TINTE",
                        detalle: "Magenta a verde",
                        clave: \.tinte
                    )

                    filaEfectoSignado(
                        titulo: "LUCES",
                        detalle: "Recupera las luces que revientan",
                        clave: \.highlights,
                        valorNeutro: 1,
                        rango: 0...1
                    )

                    filaEfectoSignado(
                        titulo: "SOMBRAS",
                        detalle: "Aclara u oscurece las sombras",
                        clave: \.shadows,
                        valorNeutro: 0
                    )

                    filaEfectoSignado(
                        titulo: "VIBRANCE",
                        detalle: "Saturacion inteligente sin quemar",
                        clave: \.vibrance,
                        valorNeutro: 0
                    )

                    filaEfecto(
                        titulo: "NITIDEZ",
                        detalle: "Detalle fino",
                        clave: \.sharpen
                    )

                    filaEfecto(
                        titulo: "GLOW",
                        detalle: "Halo brillante alrededor de las luces",
                        clave: \.glow
                    )

                    filaEfecto(
                        titulo: "FRINGE",
                        detalle: "Aberracion cromatica en los bordes",
                        clave: \.fringe
                    )

                    filaEfecto(
                        titulo: "VIGNETTE",
                        detalle: "Oscurece las esquinas",
                        clave: \.vignette
                    )

                    filaEfecto(
                        titulo: "MOTION",
                        detalle: "Desenfoque de movimiento",
                        clave: \.motion
                    )

                    filaEfecto(
                        titulo: "HALATION",
                        detalle: "Halo calido en las luces fuertes",
                        clave: \.halation
                    )

                    filaEfecto(
                        titulo: "DUST",
                        detalle: "Motas de polvo de pelicula",
                        clave: \.dust
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

                    filaEstilo

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

                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
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

    /// Muestra grande de la fecha. Va hasta arriba de la hoja para que se vea
    /// aunque el panel tape la parte de abajo de la foto.
    private var vistaPreviaFecha: some View {
        HStack(spacing: 10) {
            Text("FECHA")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Spacer(minLength: 8)

            if sello.encendido || preset.rotulo != nil {
                TimelineView(.periodic(from: .now, by: 1)) { contexto in
                    VStack(alignment: .trailing, spacing: 2) {
                        if let rotulo = preset.rotulo {
                            let f = controles.estiloFecha.fuente(12)
                            Text(rotulo)
                                .font(.custom(f.fontName, size: f.pointSize))
                                .tracking(controles.estiloFecha.interletra * 12)
                                .foregroundStyle(
                                    Color(uiColor: controles.estiloFecha.color).opacity(0.85)
                                )
                        }

                        if sello.encendido {
                            let f = controles.estiloFecha.fuente(21)
                            Text(SelloFecha.texto(sello, fecha: contexto.date))
                                .font(.custom(f.fontName, size: f.pointSize))
                                .foregroundStyle(Color(uiColor: controles.estiloFecha.color))
                                .multilineTextAlignment(.trailing)
                                .shadow(color: .black.opacity(0.6), radius: 2, x: 1, y: 1)
                        }
                    }
                }
            } else {
                Text("Sin fecha")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                        Text(LocalizedStringKey(sello.tituloMenu))
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

    /// Elige la tipografia con la que se quema la fecha.
    private var filaEstilo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("TIPOGRAFIA")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EstiloFecha.allCases) { estilo in
                        Button {
                            controles.estiloFecha = estilo
                        } label: {
                            let f = estilo.fuente(15)
                            Text(muestra(estilo))
                                .font(.custom(f.fontName, size: f.pointSize))
                                .foregroundStyle(Color(uiColor: estilo.color))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(
                                            controles.estiloFecha == estilo ? 0.22 : 0.08
                                        ))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            Color.white.opacity(
                                                controles.estiloFecha == estilo ? 0.8 : 0.15
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Text("Asi se ve la fecha quemada")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    /// Muestra de la fecha. Si esta apagada igual enseña como quedaria.
    private func muestra(_ estilo: EstiloFecha) -> String {
        let modo = (sello == .apagado) ? SelloFecha.dazz : sello
        return SelloFecha.texto(modo).replacingOccurrences(of: "\n", with: " ")
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

    /// Fila de -100 a +100 para los ajustes finos del editor.
    private func filaAjuste(
        titulo: String,
        detalle: String,
        clave: WritableKeyPath<ControlesLook, CGFloat?>
    ) -> some View {
        let valor = Binding(
            get: { controles[keyPath: clave] ?? 0 },
            set: { controles[keyPath: clave] = $0 }
        )

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Text(textoAjuste(valor.wrappedValue))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
            }

            Slider(value: valor, in: -1...1)
                .tint(.white)

            Text(detalle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    /// Fila -100..100 con neutro propio (luces neutro 100, sombras 0...).
    private func filaEfectoSignado(
        titulo: String,
        detalle: String,
        clave: WritableKeyPath<ControlesLook, CGFloat?>,
        valorNeutro: CGFloat,
        rango: ClosedRange<CGFloat>? = nil
    ) -> some View {
        let valor = Binding(
            get: { controles[keyPath: clave] ?? valorNeutro },
            set: { controles[keyPath: clave] = $0 }
        )
        let limites = rango ?? (valorNeutro - 1)...(valorNeutro + 1)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int((valor.wrappedValue * 100).rounded()))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
            }

            Slider(value: valor, in: limites)
                .tint(.white)

            Text(detalle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    /// Fila 0..100 para efectos de pelicula (apagado = 0).
    private func filaEfecto(
        titulo: String,
        detalle: String,
        clave: WritableKeyPath<ControlesLook, CGFloat?>
    ) -> some View {
        let valor = Binding(
            get: { controles[keyPath: clave] ?? 0 },
            set: { controles[keyPath: clave] = $0 > 0.001 ? $0 : nil }
        )

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int((valor.wrappedValue * 100).rounded()))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
            }

            Slider(value: valor, in: 0...1)
                .tint(.white)

            Text(detalle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func textoAjuste(_ valor: CGFloat) -> String {
        let numero = Int((valor * 100).rounded())
        return numero > 0 ? "+\(numero)" : "\(numero)"
    }

    private func fila(
        titulo: String,
        detalle: String,
        valor: Binding<CGFloat>,
        rango: ClosedRange<CGFloat>,
        maximo: CGFloat
    ) -> some View {        VStack(alignment: .leading, spacing: 7) {
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