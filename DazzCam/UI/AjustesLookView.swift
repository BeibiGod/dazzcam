import SwiftUI

/// Control del look. Secciones separadas: ADJUST, EFFECTS, DATE, FRAMES.
/// Se aplica a foto y video, importado o tomado. "EDIT".
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
                VStack(spacing: 14) {
                    vistaPreviaFecha

                    Text("Muevelo y mira el cambio.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))

                    filaNav("ADJUST", icono: "slider.horizontal.3") { ajustesSeguros }
                    filaNav("EFFECTS", icono: "sparkles") { efectos }
                    filaNav("DATE", icono: "calendar") { fechaSeparada }

                    // FRAMES (plain/specs/white/paper/instant/film) se eligen
                    // en la fila de marcos, con lo que corresponde.
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("EDIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { cerrar() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func filaNav<Contenido: View>(
        _ titulo: String,
        icono: String,
        @ViewBuilder _ contenido: @escaping () -> Contenido
    ) -> some View {
        NavigationLink {
            ScrollView {
                contenido()
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icono)
                    .font(.system(size: 14, weight: .semibold))
                Text(titulo)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var ajustesSeguros: some View {
        VStack(spacing: 16) {
            fila(
                titulo: "INTENSIDAD",
                detalle: "Baja todo el look. Lo que muevas a mano se queda",
                valor: $controles.intensidad,
                rango: 0...1,
                maximo: 1
            )

            filaAjuste(titulo: "EXPOSICION", detalle: "Aclara u oscurece toda la foto", clave: \.exposicion)
            filaAjuste(titulo: "WARMTH", detalle: "Azul de noche a calido de tarde", clave: \.temperatura)
            filaAjuste(titulo: "CONTRASTE", detalle: "Separa mas las luces de las sombras", clave: \.contraste)
            filaEfectoSignado(titulo: "HIGHLIGHTS", detalle: "Recupera las luces que revientan", clave: \.highlights, valorNeutro: 1, rango: 0...1)
            filaEfectoSignado(titulo: "SHADOWS", detalle: "Aclara u oscurece las sombras", clave: \.shadows, valorNeutro: 0)
            filaAjuste(titulo: "SATURACION", detalle: "De gris apagado a color intenso", clave: \.saturacion)
            filaAjuste(titulo: "TINT", detalle: "Magenta a verde", clave: \.tinte)
            filaEfectoSignado(titulo: "VIBRANCE", detalle: "Saturacion inteligente sin quemar", clave: \.vibrance, valorNeutro: 0)
            filaEfecto(titulo: "SHARPEN", detalle: "Detalle fino", clave: \.sharpen)

            Text("CURVE / HSL / GRADING / WHITES / BLACKS / HARMONY / WASH / CALIBRATION / FADE: aun no verificadas; no invento sliders sin ver resultado.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var efectos: some View {
        VStack(spacing: 16) {
            fila(titulo: "GRAIN", detalle: "Textura de pelicula", valor: opcional(\.grano, sugerido: sugerido.grano), rango: 0...0.35, maximo: 0.35)

            // rayones/fuga usan la tabla de la camara como sugerido.
            efectoOpcional(titulo: "SCRATCHES", detalle: "Rayones finos de pelicula vieja", clave: \.rayones, sugerido: sugerido.rayones)
            efectoOpcional(titulo: "LIGHTLEAKS", detalle: "Luz que se cuela por una esquina", clave: \.fuga, sugerido: sugerido.fuga)

            filaEfecto(titulo: "MOTION", detalle: "Desenfoque de movimiento", clave: \.motion)
            filaEfecto(titulo: "HALATION", detalle: "Halo calido en las luces fuertes", clave: \.halation)
            filaEfecto(titulo: "DUST", detalle: "Motas de polvo de pelicula", clave: \.dust)
            filaEfecto(titulo: "GLOW", detalle: "Halo brillante alrededor de las luces", clave: \.glow)
            filaEfecto(titulo: "FRINGE", detalle: "Aberracion cromatica en los bordes", clave: \.fringe)
            filaEfecto(titulo: "VIGNETTE", detalle: "Oscurece las esquinas", clave: \.vignette)
        }
    }

    private var fechaSeparada: some View {
        VStack(alignment: .leading, spacing: 18) {
            seccionFecha("DATE") { filaFecha }
            seccionFecha("TYPOGRAPHY") { filaEstilo }
            seccionFecha("AUTOMATIC") { filaAutomatica }
        }
    }

    private func seccionFecha<Contenido: View>(_ titulo: String, @ViewBuilder _ contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            contenido()
        }
    }

    /// AUTOMATIC = dia que se tomo. Se usa la fecha original (EXIF) cuando hay.
    private var filaAutomatica: some View {
        Button {
            sello = .automatico
        } label: {
            HStack(spacing: 10) {
                Image(systemName: sello == .automatico ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day it was taken")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("Fecha original de la foto/video; si no hay, hoy.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func efectoOpcional(
        titulo: String,
        detalle: String,
        clave: WritableKeyPath<ControlesLook, CGFloat?>,
        sugerido: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Spacer()
                Text("\(Int(((controles[keyPath: clave] ?? sugerido) * 100).rounded()))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).monospacedDigit()
            }
            Slider(value: opcional(clave, sugerido: sugerido), in: 0...1).tint(.white)
            Text(detalle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
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