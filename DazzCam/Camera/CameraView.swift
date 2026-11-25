import SwiftUI
import Combine
import UIKit
import PhotosUI
import UniformTypeIdentifiers

/// Pantalla de camara completa: visor, lentes, zoom de pellizco, enfoque,
/// temporizador, exposicion, flash, proporcion, video e IA.
struct CameraView: View {
    @StateObject private var camara = CameraSession()
    @StateObject private var foto = PhotoCapture()
    @StateObject private var vivo = LiveFilterPreview()
    @StateObject private var miniaturas = FilterThumbnails()
    @StateObject private var video = MovieRecorder()
    @StateObject private var nivel = Nivel()
    @StateObject private var rastreador = RastreadorSujeto()
    @Environment(\.scenePhase) private var fase

    @State private var preparado = false
    @State private var mostrarCaptura = false
    @State private var mostrarTodas = false
    @State private var mostrarIA = false
    @State private var aviso: String?
    @State private var preset: FilterPreset = .dazzClassic
    @State private var fotoFiltrada: UIImage?
    @State private var modoVivo = true
    @State private var anillo: CGPoint?
    @State private var analisis: Analisis?
    @State private var guia: Guia?
    @State private var mostrarGuia = false
    @State private var tamanoGuia: CGSize?
    @State private var analizando = false
    @State private var halago: String?
    @State private var cuentaGuia: Int?
    @State private var tareaCuenta: Task<Void, Never>?
    @State private var volvioA1x = false
    @State private var sujetoEsCara = false
    @State private var zoomPendiente: CGFloat?
    @State private var zoomDesde = Date()
    @State private var zoomEnfriando = Date.distantPast
    @State private var modo: ModoCaptura = .foto
    @State private var vivoAntesDeGrabar = true

    @State private var zoomBase: CGFloat = 1
    @State private var flashEncendido = false
    @State private var temporizador: Temporizador = .apagado
    @State private var proporcion: Proporcion = .dieciseisNueve
    @State private var exposicion: Double = 0
    @State private var exposicionInicioArrastre: Double?
    @State private var cuenta: Int?
    @AppStorage("beibi.cuadricula") private var mostrarCuadricula = true
    @AppStorage(Idioma.clave) private var idioma: Idioma = .es
    @State private var sello: SelloFecha = .dazz
    @State private var destello: Double = 0
    @State private var mostrarImportar = false
    @State private var fotoElegida: PhotosPickerItem?
    @State private var fotoImportada: UIImage?
    @State private var mostrarEditor = false
    @State private var videoImportado: URL?
    @State private var mostrarEditorVideo = false
    @State private var videoGrabado: URL?
    @State private var fechaVideoGrabado = Date()
    @State private var mostrarRevisionVideo = false
    @State private var controles = ControlesLook()
    @State private var mostrarAjustes = false
    @State private var mostrarAjustesCamara = false
    @State private var favoritas = Preferencias.cargarFavoritas()
    @State private var puntoExposicion: CGPoint?
    @State private var barraExposicionVisible = false
    @State private var tokenExposicion = 0
    @State private var tokenAjuste = 0
    @State private var guardandoFoto = false
    @State private var semillaCaptura: UInt64 = 0
    @State private var semillaVivo = UInt64.random(in: 1...UInt64.max)
    @State private var semillaVideo: UInt64 = 0

    /// Al abrir, retoma la ultima camara, fecha y look que dejo el usuario.
    init() {
        let guardado = Preferencias.cargar()
        _preset = State(initialValue: guardado?.preset ?? .dazzClassic)
        _sello = State(initialValue: guardado?.sello ?? .dazz)
        _controles = State(initialValue: guardado?.controles ?? ControlesLook())
    }

    private var textoVivo: String {
        guard modoVivo else { return "VIVO" }
        return vivo.cuadrosPorSegundo > 0 ? "VIVO \(vivo.cuadrosPorSegundo)" : "VIVO"
    }

    private func guardarPreferencias() {
        Preferencias.guardar(
            preset: preset,
            sello: sello,
            controles: controles
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                visor(geo)

                if let n = cuentaGuia, guia == nil {
                    Text("\(n)")
                        .font(.system(size: 86, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.55), radius: 18)
                        .transition(.opacity)
                }

                if let cuenta = cuenta {
                    Text("\(cuenta)")
                        .font(.system(size: 130, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 20)
                        .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 0) {
                    cabecera
                        .padding(.top, insetArriba + 6)

                    Spacer(minLength: 0)

                    if sello.encendido || preset.rotulo != nil {
                        let night = controles.estiloFecha == .vision || preset.rotulo == "NIGHTSHOT"

                        HStack {
                            if !night { Spacer() }

                            TimelineView(.periodic(from: .now, by: 1)) { contexto in
                                VStack(alignment: night ? .center : .trailing, spacing: 2) {
                                    let fRotulo = controles.estiloFecha.fuente(11)
                                    if let rotulo = preset.rotulo {
                                        Text(rotulo)
                                            .font(.custom(fRotulo.fontName, size: fRotulo.pointSize))
                                            .tracking(controles.estiloFecha.interletra * 11)
                                            .foregroundStyle(
                                                Color(uiColor: controles.estiloFecha.color)
                                                    .opacity(0.95)
                                            )
                                            .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 1)
                                    }

                                    if sello.encendido {
                                        let fFecha = controles.estiloFecha.fuente(13)
                                        Text(SelloFecha.texto(sello, fecha: contexto.date))
                                            .font(.custom(fFecha.fontName, size: fFecha.pointSize))
                                            .foregroundStyle(
                                                Color(uiColor: controles.estiloFecha.color)
                                            )
                                            .multilineTextAlignment(night ? .center : .trailing)
                                            .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 1)
                                    }
                                }
                            }

                            if !night { Spacer().frame(width: 0) } else { Spacer() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.bottom, night ? 14 : 6)
                    }

                    if mostrarGuia, analisis != nil {
                        barraGuia(guia: guia, puntaje: puntajeEnVivo)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    if mostrarGuia {
                        instruccionGuia(guia)
                            .padding(.bottom, 10)
                    }

                    if analizando, !mostrarGuia {
                        Text("Buscando tu toma...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(.bottom, 8)
                    }

                    barraInferior
                        .padding(.bottom, 8)

                    if let texto = aviso {
                        Text(texto)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.65), in: Capsule())
                            .padding(.bottom, 6)
                    }

                    if let error = foto.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.75), in: Capsule())
                            .padding(.bottom, 6)
                    }

                    if let error = video.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.75), in: Capsule())
                            .padding(.bottom, 6)
                    }

                    barraCamaras
                }
                .frame(width: geo.size.width)

                if mostrarCaptura, let imagen = fotoFiltrada {
                    ZStack {
                        Color.black

                        // La foto se acomoda arriba de los controles para
                        // que la fecha quemada nunca quede tapada.
                        VStack(spacing: 0) {
                            FotoZoom(imagen: imagen)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.horizontal, 6)
                                .padding(.top, insetArriba + 42)

                            Spacer(minLength: 0)
                                .frame(height: 220)
                        }

                        VStack {
                            HStack {
                                Spacer()

                                Button {
                                    descartarCaptura()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(.black.opacity(0.55), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(guardandoFoto)
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, insetArriba + 6)

                            Spacer()
                        }

                        VStack {
                            Spacer()

                            VStack(spacing: 10) {
                                FilaFecha(
                                    sello: $sello,
                                    estilo: controles.estiloFecha,
                                    rotulo: preset.rotulo
                                )

                                HStack(spacing: 10) {
                                    Text("INTENSIDAD")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.65))

                                    Slider(value: $controles.intensidad, in: 0...1)
                                        .tint(.white)

                                    Text("\(Int((controles.intensidad * 100).rounded()))%")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .monospacedDigit()
                                        .frame(width: 38, alignment: .trailing)
                                }

                                HStack(spacing: 10) {
                                    Button {
                                        mostrarAjustes = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 11, weight: .semibold))
                                            Text("MÁS AJUSTES")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.14), in: Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        guardarCaptura()
                                    } label: {
                                        Text(guardandoFoto ? "GUARDANDO" : "GUARDAR")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.white, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(guardandoFoto)
                                }

                                Text("GUARDAR la manda a tu fototeca")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(14)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 14)
                            .padding(.bottom, insetAbajo + 10)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.opacity)
                }

                if destello > 0 {
                    Color.white
                        .opacity(destello)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .task {
            if !preparado {
                preparado = true
                _ = foto.conectar(a: camara.session)
                _ = vivo.conectar(a: camara.session)
                video.conectar(a: camara.session)
                vivo.preset = preset
                vivo.controles = controles
                vivo.semilla = semillaVivo
                vivo.rastreador = rastreador
            }
            await camara.arrancar()
            camara.ponerZoom(1)
            zoomBase = camara.zoom
            if mostrarCuadricula {
                nivel.empezar()
            }
        }
        .onDisappear {
            rastreador.parar()
            detenerCuentaGuia()
            nivel.parar()
            camara.detener()
        }
        .onChange(of: mostrarGuia) { _, abierto in
            if abierto {
                sujetoEsCara = false
                rastreador.empezar()
            } else {
                rastreador.parar()
                detenerCuentaGuia()
                halago = nil
                guia = nil
                analisis = nil
                volvioA1x = true
                sujetoEsCara = false
                zoomPendiente = nil

                if abs(camara.zoom - 0.5) < 0.08 {
                    camara.ponerZoom(1)
                    zoomBase = camara.zoom
                }
            }
        }
        .onReceive(
            rastreador.$caja
                .combineLatest(rastreador.$esCara, rastreador.$buscando)
        ) { caja, esCara, buscando in
            guard mostrarGuia else { return }

            if let caja = caja,
               let nueva = AestheticAnalyzer.guia(
                   paraCaja: caja,
                   esCara: esCara,
                   destinoAnterior: guia?.destino,
                   estabaListo: guia?.listo ?? false,
                   grados: nivel.angulo * 180 / .pi
               ) {
                sujetoEsCara = esCara
                let tamano = vivo.imagen?.size ?? tamanoGuia ?? CGSize(width: 9, height: 16)
                refrescarGuia(nueva, tamano: tamano)
            } else if buscando {
                withAnimation(.easeOut(duration: 0.18)) {
                    guia = nil
                }
            }
        }
        .onChange(of: fase) { _, nueva in
            // Al volver a entrar a la app siempre arranca en 1x y 16:9.
            guard nueva == .active else { return }
            camara.ponerZoom(1)
            zoomBase = camara.zoom
            proporcion = .dieciseisNueve

            // Cada vez que entras, la fuga y el rayado del visor son otros.
            semillaVivo = UInt64.random(in: 1...UInt64.max)
            vivo.semilla = semillaVivo
        }
        .onChange(of: modoVivo) { _, activo in
            vivo.activo = activo
        }
        .onChange(of: mostrarCuadricula) { _, activo in
            if activo {
                nivel.empezar()
            } else {
                nivel.parar()
            }
        }
        .onChange(of: favoritas) { _, nuevas in
            Preferencias.guardarFavoritas(nuevas)
        }
        .onChange(of: preset) { _, nuevo in
            vivo.preset = nuevo
            // Cada camara prende su sello y su tipografia, como de fabrica.
            sello = nuevo.selloDeFabrica
            controles.estiloFecha = nuevo.estiloDeFecha
            guardarPreferencias()
            if mostrarCaptura {
                programarRecalculo()
            }
        }
        .onChange(of: controles) { _, nuevo in
            vivo.controles = nuevo
            guardarPreferencias()
            if mostrarCaptura {
                programarRecalculo()
            }
        }
        .onChange(of: sello) { _, _ in
            guardarPreferencias()
            if mostrarCaptura {
                programarRecalculo()
            }
        }
        .onChange(of: video.grabando) { _, grabando in
            if grabando {
                vivoAntesDeGrabar = modoVivo
                modoVivo = false
            } else if vivoAntesDeGrabar {
                modoVivo = true
            }
        }
        .onChange(of: video.grabacionLista) { _, lista in
            guard let lista = lista else { return }
            videoGrabado = lista
            fechaVideoGrabado = video.fechaGrabacion
            mostrarRevisionVideo = true
        }
        .onChange(of: foto.capturas) { _, _ in
            guard let base = foto.ultimaFoto else { return }

            if !miniaturas.lista {
                miniaturas.generar(desde: base)
            }

            semillaCaptura = UInt64.random(in: 1...UInt64.max)

            fotoFiltrada = Self.componer(
                base,
                look: preset,
                ajustes: controles,
                relacion: proporcion.relacion,
                marca: sello,
                semilla: semillaCaptura
            )
            mostrarGuia = false
            mostrarCaptura = true

            // La siguiente foto y el visor estrenan fuga y rayado.
            semillaVivo = UInt64.random(in: 1...UInt64.max)
            vivo.semilla = semillaVivo
        }
        .onReceive(vivo.$imagen) { imagen in
            guard let imagen = imagen, !miniaturas.lista else { return }
            miniaturas.generar(desde: imagen)
        }
        .sheet(isPresented: $mostrarTodas) {
            CameraPickerSheet(
                seleccionado: $preset,
                favoritas: $favoritas,
                muestras: miniaturas.muestras
            )
        }
        .sheet(isPresented: $mostrarAjustes) {
            AjustesLookView(controles: $controles, sello: $sello, preset: preset)
                .presentationDetents([.height(660)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(red: 0.06, green: 0.06, blue: 0.08))
        }
        .sheet(isPresented: $mostrarAjustesCamara) {
            AjustesCamaraView(
                idioma: $idioma,
                proporcion: $proporcion,
                mostrarCuadricula: $mostrarCuadricula
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(red: 0.06, green: 0.06, blue: 0.08))
        }
        .sheet(isPresented: $mostrarIA) {
            if let analisis = analisis {
                AIView(
                    analisis: analisis,
                    alElegirCamara: { sugerida in
                        preset = sugerida
                        mostrarIA = false
                    },
                    alVerTodas: {
                        mostrarIA = false
                        abrirCatalogo()
                    }
                )
            }
        }
        .photosPicker(
            isPresented: $mostrarImportar,
            selection: $fotoElegida,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: fotoElegida) { _, item in
            guard let item = item else { return }

            Task {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let archivo = try? await item.loadTransferable(type: VideoFile.self) {
                        videoImportado = archivo.url
                        mostrarEditorVideo = true
                    } else {
                        aviso = L("No pude abrir ese video")
                    }
                } else if let datos = try? await item.loadTransferable(type: Data.self),
                          let imagen = UIImage(data: datos) {
                    fotoImportada = imagen
                    mostrarEditor = true
                } else {
                    aviso = L("No pude abrir esa foto")
                }
                fotoElegida = nil
            }
        }
        .sheet(isPresented: $mostrarEditorVideo, onDismiss: {
            if let url = videoImportado {
                try? FileManager.default.removeItem(at: url)
            }
            videoImportado = nil
        }) {
            if let url = videoImportado {
                VideoEditorView(
                    url: url,
                    preset: preset,
                    controles: controles,
                    sello: sello
                ) { elegido in
                    preset = elegido
                    aviso = L("Video guardado con %@", elegido.nombre)
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        aviso = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $mostrarRevisionVideo, onDismiss: {
            if let url = videoGrabado {
                try? FileManager.default.removeItem(at: url)
            }
            videoGrabado = nil

            // Al volver al visor, estrena fuga y rayado.
            semillaVivo = UInt64.random(in: 1...UInt64.max)
            vivo.semilla = semillaVivo
        }) {
            if let url = videoGrabado {
                VideoEditorView(
                    url: url,
                    preset: preset,
                    controles: controles,
                    sello: sello,
                    fecha: fechaVideoGrabado,
                    semilla: semillaVideo,
                    esRevision: true
                ) { elegido in
                    preset = elegido
                    aviso = L("Video guardado con %@", elegido.nombre)
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        aviso = nil
                    }
                }
            }
        }
        .sheet(isPresented: $mostrarEditor) {
            if let fotoImportada = fotoImportada {
                PhotoEditorView(
                    imagen: fotoImportada,
                    preset: preset,
                    proporcion: proporcion,
                    sello: sello,
                    controles: controles,
                    alGuardar: { _, elegido in
                        preset = elegido
                        aviso = L("Copia guardada con %@", elegido.nombre)
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            aviso = nil
                        }
                    }
                )
            }
        }
    }

    // MARK: - Medidas del sistema

    private var ventana: UIWindow? {
        let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for escena in escenas {
            if let principal = escena.windows.first(where: { $0.isKeyWindow }) {
                return principal
            }
        }
        return escenas.first?.windows.first
    }

    private var insetArriba: CGFloat {
        let valor = ventana?.safeAreaInsets.top ?? 0
        return valor > 0 ? valor : 47
    }

    private var insetAbajo: CGFloat {
        let valor = ventana?.safeAreaInsets.bottom ?? 0
        return valor > 0 ? valor : 30
    }

    // MARK: - Visor

    /// Alto de las barras negras cuando esta en 16:9.
    private func alturaBarra(_ geo: GeometryProxy) -> CGFloat {
        guard let relacion = proporcion.relacion else { return 0 }
        let alto = geo.size.width / relacion
        return max(0, (geo.size.height - alto) / 2)
    }

    private func visor(_ geo: GeometryProxy) -> some View {
        let barra = alturaBarra(geo)

        return ZStack {
            visorBase

            if barra > 0 {
                VStack(spacing: 0) {
                    Color.black.frame(height: barra)
                    Spacer(minLength: 0)
                    Color.black.frame(height: barra)
                }
                .allowsHitTesting(false)
            }

            if mostrarCuadricula {
                GridNivel(angulo: nivel.angulo, estable: nivel.estable)
                    .padding(.vertical, barra)
            }

            if mostrarGuia {
                if let guia = guia {
                    guiaDeSujeto(
                        guia,
                        etiqueta: etiquetaGuia,
                        en: geo.size
                    )
                } else if rastreador.buscando || analizando {
                    miraIA
                }
            } else if analizando {
                miraIA
            }

            if let punto = puntoExposicion, barraExposicionVisible {
                BarraExposicion(valor: exposicion)
                    .position(
                        x: min(max(punto.x + 66, 40), geo.size.width - 40),
                        y: min(max(punto.y, barra + 100), geo.size.height - barra - 100)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { valor in
                    camara.ponerZoom(zoomBase * valor.magnification)
                }
                .onEnded { _ in
                    zoomBase = camara.zoom
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { gesto in
                    guard barraExposicionVisible, cuenta == nil, !mostrarCaptura else { return }
                    guard abs(gesto.translation.height) >= abs(gesto.translation.width) else { return }

                    if exposicionInicioArrastre == nil {
                        exposicionInicioArrastre = exposicion
                        // Mientras arrastras, la barrita no se esconde.
                        tokenExposicion += 1
                    }

                    let inicio = exposicionInicioArrastre ?? exposicion
                    let recorrido = max(Double(geo.size.height) * 0.42, 220)
                    let cambio = -Double(gesto.translation.height) / recorrido * 3.0
                    let nuevo = min(max(inicio + cambio, -2), 2)

                    exposicion = nuevo
                    camara.fijarExposicion(Float(nuevo))
                }
                .onEnded { _ in
                    guard exposicionInicioArrastre != nil else { return }
                    exposicionInicioArrastre = nil
                    mantenerBarraExposicion()
                }
        )
    }

    private var visorBase: some View {
        ZStack {
            CameraPreviewView(
                session: camara.session,
                alTocar: { puntoCamara, puntoPantalla in
                    camara.enfocar(en: puntoCamara)
                    mostrarAnillo(en: puntoPantalla)
                    mostrarBarraExposicion(en: puntoPantalla)
                },
                alTocarDoble: {
                    voltearCamara()
                }
            )

            if modoVivo, let imagenViva = vivo.imagen {
                Image(uiImage: imagenViva)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
            }

            if let punto = anillo {
                FocusRing()
                    .position(x: punto.x, y: punto.y)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Guia de encuadre

    /// Recuadro que sigue al sujeto, como en Framed: amarillo mientras hay
    /// que moverse y verde cuando ya quedo bien.
    private func guiaDeSujeto(_ guia: Guia, etiqueta: String, en tamano: CGSize) -> some View {
        let rect = rectDePantalla(guia.sujeto, en: tamano)
        let color = guia.listo ? Self.verdeGuia : Self.amarilloGuia
        let objetivo = puntoDePantalla(guia.destino, en: tamano)
        let destinoRect = CGRect(
            x: objetivo.x - rect.width / 2,
            y: objetivo.y - rect.height / 2,
            width: rect.width,
            height: rect.height
        )

        return ZStack {
            // Marco de la toma que encontro la IA: esquinas, como el
            // recuadro de una camara. Ahi debe caer el sujeto.
            if !guia.encuadrado {
                // Linea punteada: de donde esta el sujeto a donde debe caer.
                if hypot(objetivo.x - rect.midX, objetivo.y - rect.midY) > 34 {
                    Path { camino in
                        camino.move(to: CGPoint(x: rect.midX, y: rect.midY))
                        camino.addLine(to: objetivo)
                    }
                    .stroke(
                        color.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])
                    )
                    .allowsHitTesting(false)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.16), lineWidth: 1)

                    MarcoToma()
                        .stroke(
                            color.opacity(0.9),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                }
                .frame(width: destinoRect.width, height: destinoRect.height)
                .position(x: destinoRect.midX, y: destinoRect.midY)

                // Punto donde debe caer el centro del sujeto.
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .position(x: objetivo.x, y: objetivo.y)

                // Flecha en el borde: hacia donde mover el telefono.
                flechasGuia(sujeto: rect, destino: objetivo, en: tamano, color: color)
            }

            // Recuadro del sujeto. Cuando queda listo se pone verde y se
            // queda ahi, como el marco que se cierra en Framed.
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color, lineWidth: guia.listo ? 3.5 : 3)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: color.opacity(guia.listo ? 0.55 : 0.4), radius: guia.listo ? 6 : 3)

            etiquetaSujeto(etiqueta, color: color)
                .position(
                    x: min(max(rect.midX, 84), tamano.width - 84),
                    y: (rect.maxY + 22 > tamano.height - 196)
                        ? rect.minY - 18
                        : rect.maxY + 22
                )
        }
        .animation(.easeOut(duration: 0.16), value: guia.listo)
        .animation(.easeOut(duration: 0.12), value: rect.midX)
        .animation(.easeOut(duration: 0.12), value: rect.midY)
        .allowsHitTesting(false)
    }

    /// Flecha en el borde que muestra hacia donde mover el telefono. Una
    /// sola, en el eje que mas falta, como en Framed.
    private func flechasGuia(
        sujeto: CGRect,
        destino: CGPoint,
        en tamano: CGSize,
        color: Color
    ) -> some View {
        let dx = destino.x - sujeto.midX
        let dy = destino.y - sujeto.midY

        return ZStack {
            if abs(dx) >= abs(dy), abs(dx) > 18 {
                // El sujeto tiene que ir a la derecha: el telefono va a la
                // izquierda, por eso la flecha va al borde izquierdo.
                Image(systemName: dx > 0 ? "chevron.left" : "chevron.right")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(color.opacity(0.95))
                    .shadow(color: .black.opacity(0.55), radius: 5)
                    .position(
                        x: dx > 0 ? 26 : tamano.width - 26,
                        y: tamano.height * 0.46
                    )
            } else if abs(dy) > 18 {
                Image(systemName: dy > 0 ? "chevron.up" : "chevron.down")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(color.opacity(0.95))
                    .shadow(color: .black.opacity(0.55), radius: 5)
                    .position(
                        x: tamano.width * 0.5,
                        y: dy > 0 ? 118 : tamano.height - 214
                    )
            }
        }
    }

    private var etiquetaGuia: String {
        if sujetoEsCara {
            return L("persona")
        }
        if let etiqueta = analisis?.etiqueta, !etiqueta.isEmpty {
            return etiqueta
        }
        return L("sujeto")
    }

    /// Puntaje que sube y baja con el encuadre, como en Framed: toma la
    /// calidad de la escena y le suma que tan bien esta puesto el sujeto.
    private var puntajeEnVivo: Int {
        guard let guia else { return analisis?.puntaje ?? 0 }

        let base = Double(analisis?.puntaje ?? 80)
        let dx = Double(abs(guia.destino.x - guia.sujeto.midX))
        let dy = Double(abs(guia.destino.y - guia.sujeto.midY))

        // 1 = el recuadro cae justo en su cruce; 0 = anda lejos.
        let desvio = min(1, hypot(dx / 0.30, dy / 0.34))
        let centrado = 1 - desvio

        // 1 = telefono derecho; 0 = 10 grados o mas.
        let inclinacion = abs(nivel.angulo) * 180 / .pi
        let derecho = 1 - min(1, inclinacion / 10)

        // 1 = el sujeto ocupa una buena parte del cuadro.
        let tamano = Double(guia.sujeto.height)
        let medida = max(0, 1 - abs(tamano - 0.52) / 0.34)

        let calidadBase = centrado * 0.55 + derecho * 0.30 + medida * 0.15

        // Cuando la IA ya dio el encuadre por bueno, el puntaje sube de
        // golpe: se siente como cerrar la toma, igual que en Framed.
        let calidad = guia.listo ? max(calidadBase, 0.94) : calidadBase
        return max(0, min(100, Int((base - 18 + 26 * calidad).rounded())))
    }

    /// Pasa un punto normalizado de la foto a la pantalla (misma proyeccion que
    /// la vista previa recortada).
    private func puntoDePantalla(_ normalizado: CGPoint, en tamano: CGSize) -> CGPoint {
        let foto = tamanoGuia ?? vivo.imagen?.size ?? CGSize(width: 9, height: 16)

        guard foto.width > 1, foto.height > 1 else {
            return CGPoint(x: tamano.width / 2, y: tamano.height / 2)
        }

        let escala = max(tamano.width / foto.width, tamano.height / foto.height)
        let dibujo = CGSize(
            width: foto.width * escala,
            height: foto.height * escala
        )
        let x0 = (tamano.width - dibujo.width) / 2
        let y0 = (tamano.height - dibujo.height) / 2

        return CGPoint(
            x: x0 + normalizado.x * dibujo.width,
            y: y0 + normalizado.y * dibujo.height
        )
    }

    /// Nombre de lo que la IA esta viendo, pegado a la caja.
    private func etiquetaSujeto(_ texto: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(texto)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.38), in: Capsule())
    }

    /// Mira chiquita mientras la IA busca al sujeto.
    private var miraIA: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                .frame(width: 30, height: 30)

            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 1, height: 12)

            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 12, height: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private static let amarilloGuia = Color(red: 1.0, green: 0.86, blue: 0.18)
    private static let verdeGuia = Color(red: 0.28, green: 0.95, blue: 0.45)

    /// Pasa una caja de la foto analizada a la pantalla. La vista previa se
    /// dibuja recortada (scaledToFill), asi que se hace la misma cuenta.
    private func rectDePantalla(_ normalizado: CGRect, en tamano: CGSize) -> CGRect {
        let foto = tamanoGuia ?? vivo.imagen?.size ?? CGSize(width: 9, height: 16)

        guard foto.width > 1, foto.height > 1 else {
            return CGRect(origin: .zero, size: tamano)
        }

        let escala = max(tamano.width / foto.width, tamano.height / foto.height)
        let dibujo = CGSize(
            width: foto.width * escala,
            height: foto.height * escala
        )
        let x0 = (tamano.width - dibujo.width) / 2
        let y0 = (tamano.height - dibujo.height) / 2

        return CGRect(
            x: x0 + normalizado.minX * dibujo.width,
            y: y0 + normalizado.minY * dibujo.height,
            width: normalizado.width * dibujo.width,
            height: normalizado.height * dibujo.height
        )
    }

    /// Texto de abajo, como en Framed: "Buscando tu toma...", la instruccion
    /// para mover el telefono, y en verde cuando ya quedo.
    private func instruccionGuia(_ guia: Guia?) -> some View {
        Group {
            if let guia {
                if guia.listo {
                    Text(halago ?? L("Listo, dispara"))
                        .foregroundStyle(Self.verdeGuia)
                } else {
                    Text(guia.instruccion)
                        .foregroundStyle(.white.opacity(0.95))
                }
            } else {
                Text(analizando || rastreador.buscando
                     ? "Buscando tu toma..."
                     : "No veo un sujeto claro: apunta a algo con detalle.")
                    .foregroundStyle(.white.opacity(0.9))
            }

            // El zoom recomendado para esta escena, uno a uno.
            if let zoomRec = guia?.zoomRecomendado,
               String(format: "%.1fx", camara.zoom) != zoomRec {
                Text(zoomRec)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6), in: Capsule())
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .shadow(color: .black.opacity(0.9), radius: 5, x: 0, y: 1)
        .padding(.horizontal, 24)
        .transition(.opacity)
    }

    /// Pastilla de abajo: puntaje en vivo, acceso a las camaras y la X.
    private func barraGuia(guia: Guia?, puntaje: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    (guia?.listo ?? false) ? Self.verdeGuia : Self.amarilloGuia
                )

            Text("\(puntaje)")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text("AESTHETIC")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))

            Spacer(minLength: 6)

            Button {
                mostrarIA = true
            } label: {
                Text("CÁMARAS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    mostrarGuia = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.6), in: Capsule())
    }

    // MARK: - Encabezado

    private var cabecera: some View {
        HStack(spacing: 6) {
            herramienta(
                icono: flashEncendido ? "bolt.fill" : "bolt.slash.fill",
                texto: (camara.esFrontal && flashEncendido) ? "PANT" : nil,
                activo: flashEncendido
            ) {
                guard camara.tieneFlash || camara.esFrontal else {
                    aviso = L("Esta lente no tiene flash")
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        aviso = nil
                    }
                    return
                }
                flashEncendido.toggle()
            }

            herramienta(
                icono: "timer",
                texto: temporizador.etiqueta,
                activo: temporizador != .apagado
            ) {
                temporizador = temporizador.siguiente
            }

            Spacer(minLength: 6)

            Button {
                modoVivo.toggle()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(modoVivo ? Color.green : Color.white.opacity(0.35))
                        .frame(width: 6, height: 6)

                    Text(textoVivo)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(modoVivo ? Color.black : Color.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    modoVivo ? Color.white : Color.black.opacity(0.45),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .fixedSize()

            Button {
                mostrarAjustesCamara = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.45), in: Circle())
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ajustes")
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Herramientas

    private var barraHerramientas: some View {
        HStack(spacing: 6) {
            // Proporcion y cuadricula quedan solo en el engranaje de arriba
            // a la derecha, asi que aqui va el resto del visor.
            herramientaIcono(
                icono: "slider.horizontal.3",
                activo: !controles.automatico,
                accion: { mostrarAjustes = true }
            )

            Spacer()

            herramientaIcono(icono: "square.grid.2x2") {
                mostrarTodas = true
            }
        }
        .padding(.horizontal, 16)
    }

    private func herramientaIcono(
        icono: String,
        activo: Bool = false,
        accion: @escaping () -> Void
    ) -> some View {
        Button(action: accion) {
            Image(systemName: icono)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(activo ? Color.black : Color.white)
                .frame(width: 34, height: 34)
                .background(activo ? Color.yellow : Color.black.opacity(0.5), in: Circle())
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func herramienta(
        icono: String,
        texto: String?,
        activo: Bool,
        accion: @escaping () -> Void
    ) -> some View {
        Button(action: accion) {
            HStack(spacing: 5) {
                Image(systemName: icono)
                    .font(.system(size: 12, weight: .semibold))

                if let texto = texto {
                    Text(texto)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
            }
            .foregroundStyle(activo ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(activo ? Color.yellow : Color.black.opacity(0.5), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lentes y modo

    /// Lente mas cercana al zoom actual.
    private var lenteResaltada: Lente? {
        camara.lentes.min {
            abs(log($0.factor) - log(camara.zoom)) < abs(log($1.factor) - log(camara.zoom))
        }
    }

    /// true solo si el zoom esta pegado a una distancia tipica (0.5x, 1x, 3x).
    private var enDistanciaTipica: Bool {
        guard let cercana = lenteResaltada else { return true }
        return abs(camara.zoom - cercana.factor) / cercana.factor < 0.08
    }

    private func lenteActiva(_ lente: Lente) -> Bool {
        enDistanciaTipica && lenteResaltada == lente
    }

    /// 0.5x, 1x y 3x, centrados justo arriba del nombre de la camara.
    /// Mientras la IA guia, las lentes se atenuan y el zoom elegido se ve
    /// en amarillo, como en Framed.
    private var barraLentes: some View {
        HStack(spacing: 8) {
            ForEach(camara.lentes) { lente in
                Button {
                    camara.irA(lente)
                    zoomBase = camara.zoom
                } label: {
                    Text(lente.etiqueta)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            lenteActiva(lente)
                                ? Color.black
                                : Color.white.opacity(mostrarGuia ? 0.5 : 1)
                        )
                        .frame(width: 36, height: 36)
                        .background(
                            lenteActiva(lente)
                                ? Color.yellow
                                : Color.black.opacity(mostrarGuia ? 0.35 : 0.5),
                            in: Circle()
                        )
                        .overlay(
                            Circle().strokeBorder(
                                Color.white.opacity(lenteActiva(lente) ? 0 : 0.25),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }

            if !enDistanciaTipica {
                Text(String(format: "%.1fx", camara.zoom))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.yellow, in: Circle())
                    .fixedSize()
            }
        }
        .animation(.easeOut(duration: 0.18), value: mostrarGuia)
    }

    /// Herramientas y lentes. Los botones FOTO, VIDEO y la IA viven en la
    /// barra de abajo, junto al disparador.
    private var barraInferior: some View {
        VStack(spacing: 10) {
            barraHerramientas

            barraLentes
                .padding(.horizontal, 16)
        }
    }

    /// Barra de abajo: tira de camaras, disparador, FOTO, IA y VIDEO.
    private var barraCamaras: some View {
        CameraBar(
            seleccionado: $preset,
            modo: $modo,
            muestras: miniaturas.muestras,
            capturando: foto.capturando,
            grabando: video.grabando,
            procesando: video.procesando,
            segundos: video.segundos,
            analizando: analizando,
            favoritas: favoritas,
            listo: guia?.listo ?? false,
            alDisparar: accionDeDisparo,
            alIA: analizarEscena,
            alFavorita: alternarFavorita,
            alImportar: { mostrarImportar = true },
            alSelector: { mostrarTodas = true }
        )
        .padding(.bottom, insetAbajo + 6)
    }

    private func alternarFavorita(_ preset: FilterPreset) {
        if favoritas.contains(preset) {
            favoritas.remove(preset)
        } else {
            favoritas.insert(preset)
        }
    }

    // MARK: - Acciones

    private func accionDeDisparo() {
        switch modo {
        case .foto:
            dispararConTemporizador()

        case .video:
            if video.grabando {
                video.parar()
            } else {
                // Si la IA dejo en 0.5x, vuelve a 1x antes de grabar.
                if mostrarGuia, abs(camara.zoom - 0.5) < 0.08 {
                    camara.ponerZoom(1)
                    zoomBase = camara.zoom
                    volvioA1x = true
                }

                let azar = UInt64.random(in: 1...UInt64.max)
                semillaVivo = azar
                vivo.semilla = azar
                semillaVideo = azar

                Task {
                    await video.empezar(quitar: vivo.salida)
                }
            }
        }
    }

    private func dispararConTemporizador() {
        // Si la IA dejo en 0.5x, vuelve a 1x antes de disparar.
        if mostrarGuia, abs(camara.zoom - 0.5) < 0.08 {
            camara.ponerZoom(1)
            zoomBase = camara.zoom
            volvioA1x = true
        }

        let flashPantalla = flashEncendido && camara.esFrontal
        foto.flash = (flashEncendido && camara.tieneFlash) ? .on : .off

        let segundos = temporizador.segundos
        guard segundos > 0 else {
            dispararAhora(conDestello: flashPantalla)
            return
        }

        Task {
            for valor in stride(from: segundos, through: 1, by: -1) {
                withAnimation(.easeOut(duration: 0.15)) {
                    cuenta = valor
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            cuenta = nil
            dispararAhora(conDestello: flashPantalla)
        }
    }

    /// En selfie el flash es la pantalla en blanco, como en Instagram:
    /// primero ilumina la cara y despues dispara.
    private func dispararAhora(conDestello: Bool) {
        guard conDestello else {
            foto.disparar()
            return
        }

        Task { @MainActor in
            let pantalla = ventana?.windowScene?.screen
            let brilloAnterior = pantalla?.brightness ?? 0.5
            pantalla?.brightness = 1.0

            withAnimation(.easeOut(duration: 0.06)) {
                destello = 1
            }
            try? await Task.sleep(nanoseconds: 420_000_000)

            foto.disparar()

            withAnimation(.easeIn(duration: 0.3)) {
                destello = 0
            }
            try? await Task.sleep(nanoseconds: 320_000_000)

            pantalla?.brightness = brilloAnterior
        }
    }

    /// Actualiza la caja y la instruccion. Cuando el sujeto queda encuadrado
    /// por primera vez: vibracion, halago y acercamiento automatico, como en
    /// el video de referencia.
    private func refrescarGuia(_ nueva: Guia, tamano: CGSize) {
        let antesListo = guia?.listo ?? false
        tamanoGuia = tamano

        if nueva.listo != antesListo {
            withAnimation(.easeOut(duration: 0.18)) {
                guia = nueva
            }
        } else {
            guia = nueva
        }

        // La IA acerca sola cuando el sujeto esta lejos.
        programarZoom(nueva.zoom)

        if nueva.listo && !antesListo {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()

            withAnimation(.easeOut(duration: 0.2)) {
                halago = Self.halagos.randomElement()
            }

            volverA1xSiCorresponde()
        } else if !nueva.listo {
            if halago != nil {
                withAnimation(.easeOut(duration: 0.15)) {
                    halago = nil
                }
            }
        }
    }

    /// Cosas lindas que dice la IA cuando ya quedo el cuadro.
    private static let halagos = [
        "Buena luz, aguanta ahi",
        "Perfecto, dispara",
        "Eso es, quedate ahi",
        "Encuadre listo"
    ]

    /// Cuenta 3-2-1 mientras la IA mira la escena, como en Framed.
    private func iniciarCuentaGuia() {
        tareaCuenta?.cancel()
        cuentaGuia = 3

        tareaCuenta = Task { @MainActor in
            for numero in [3, 2, 1] {
                if Task.isCancelled || !mostrarGuia { break }
                withAnimation(.easeOut(duration: 0.15)) {
                    cuentaGuia = numero
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }

            withAnimation(.easeOut(duration: 0.25)) {
                cuentaGuia = nil
            }
        }
    }

    private func detenerCuentaGuia() {
        tareaCuenta?.cancel()
        tareaCuenta = nil
        cuentaGuia = nil
    }

    /// Acerca o aleja el zoom solo cuando la sugerencia se mantiene estable,
    /// para que no ande bombeando con el temblor del recuadro.
    private func programarZoom(_ factor: CGFloat?) {
        let ahora = Date()
        guard ahora > zoomEnfriando else { return }

        guard let factor = factor, factor > 1.25 || factor < 0.8 else {
            zoomPendiente = nil
            return
        }

        let redondeado = (factor * 10).rounded() / 10

        if let pendiente = zoomPendiente, abs(pendiente - redondeado) < 0.2 {
            if ahora.timeIntervalSince(zoomDesde) >= 1.3 {
                aplicarZoom(redondeado)
            }
        } else {
            zoomPendiente = redondeado
            zoomDesde = ahora
        }
    }

    private func aplicarZoom(_ factor: CGFloat) {
        zoomPendiente = nil
        zoomEnfriando = Date().addingTimeInterval(3.5)

        let actual = camara.zoom
        let nuevo = min(max(actual * factor, 1), 3)

        guard abs(nuevo - actual) / max(actual, 0.01) > 0.12 else { return }

        camara.ponerZoom(nuevo)
        zoomBase = camara.zoom
        volvioA1x = true

        // La caja se reescala con el zoom y sigue pegada al sujeto: la guia
        // no se borra ni se vuelve a buscar de cero.
        rastreador.reenganchar(zoom: nuevo / max(actual, 0.01))
    }

    private func analizarEscena() {
        // Si ya hay guia abierta, un toque en IA la cierra.
        if mostrarGuia {
            detenerCuentaGuia()
            withAnimation(.easeOut(duration: 0.2)) {
                mostrarGuia = false
                guia = nil
            }
            return
        }

        halago = nil
        guia = nil
        analisis = nil
        sujetoEsCara = false
        tamanoGuia = vivo.imagen?.size ?? CGSize(width: 9, height: 16)
        iniciarCuentaGuia()

        let tieneUltra = camara.lentes.contains(.ultra)

        if tieneUltra {
            volvioA1x = false
            camara.ponerZoom(0.5)
            zoomBase = camara.zoom
        } else {
            volvioA1x = true
            camara.ponerZoom(1)
            zoomBase = camara.zoom
        }

        // Abre la guia al instante.
        withAnimation(.easeOut(duration: 0.2)) {
            mostrarGuia = true
        }

        if tieneUltra {
            // Mira el entorno en 0.5x un momento y luego vuelve a 1x para guiar.
            analizando = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard mostrarGuia else {
                    analizando = false
                    return
                }

                // Vuelve a 1x: reinicia el rastreador para que siga en la nueva vista.
                volvioA1x = true
                camara.ponerZoom(1)
                zoomBase = camara.zoom
                guia = nil
                sujetoEsCara = false
                rastreador.empezar()

                try? await Task.sleep(nanoseconds: 350_000_000)
                analizando = false

                // Sugerencias de camaras en segundo plano.
                if let imagen = vivo.imagen ?? foto.ultimaFoto, mostrarGuia {
                    let resultado = await AestheticAnalyzer.analizar(imagen)
                    if mostrarGuia, let resultado = resultado {
                        analisis = resultado
                    }
                }
            }
        } else {
            // Deteccion rapida para mostrar el recuadro de una vez.
            let imagenInicial = vivo.imagen ?? foto.ultimaFoto
            if let imagenInicial = imagenInicial {
                Task {
                    if let rapida = await AestheticAnalyzer.seguir(imagenInicial), mostrarGuia {
                        tamanoGuia = imagenInicial.size
                        refrescarGuia(rapida, tamano: imagenInicial.size)
                    }
                }

                Task {
                    analizando = true
                    let resultado = await AestheticAnalyzer.analizar(imagenInicial)
                    analizando = false
                    if mostrarGuia, let resultado = resultado {
                        analisis = resultado
                    }
                }
            }
        }
    }

    /// Por si queda en 0.5x, vuelve a 1x.
    private func volverA1xSiCorresponde() {
        guard !volvioA1x else { return }
        guard abs(camara.zoom - 0.5) < 0.08 else { return }

        volvioA1x = true
        camara.ponerZoom(1)
        zoomBase = camara.zoom
    }

    private func abrirCatalogo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            mostrarTodas = true
        }
    }

    private func mostrarAnillo(en punto: CGPoint) {
        withAnimation(.easeOut(duration: 0.12)) {
            anillo = punto
        }

        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeIn(duration: 0.25)) {
                anillo = nil
            }
        }
    }

    /// Al tocar para enfocar sale la barrita de exposicion, como en la
    /// camara del iPhone. Se esconde sola a los 5 segundos.
    private func mostrarBarraExposicion(en punto: CGPoint) {
        puntoExposicion = punto

        withAnimation(.easeOut(duration: 0.18)) {
            barraExposicionVisible = true
        }

        mantenerBarraExposicion()
    }

    /// Reinicia el reloj que esconde la barrita. Se llama al soltar el dedo
    /// despues de subir o bajar la exposicion.
    private func mantenerBarraExposicion() {
        tokenExposicion += 1
        let mio = tokenExposicion

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard mio == tokenExposicion else { return }
            withAnimation(.easeIn(duration: 0.25)) {
                barraExposicionVisible = false
            }
        }
    }

    /// Cierra la revision sin guardar nada. La foto queda descartada.
    private func descartarCaptura() {
        guard !guardandoFoto else { return }

        tokenAjuste += 1
        fotoFiltrada = nil
        mostrarCaptura = false
    }

    /// Guarda la foto que estas revisando, con el look ya ajustado.
    private func guardarCaptura() {
        guard !guardandoFoto, let base = foto.ultimaFoto else { return }

        guardandoFoto = true
        tokenAjuste += 1

        // Se vuelve a componer con lo que esta puesto ahora, para que se guarde
        // justo lo que el usuario esta viendo.
        let final = Self.componer(
            base,
            look: preset,
            ajustes: controles,
            relacion: proporcion.relacion,
            marca: sello,
            semilla: semillaCaptura
        )
        fotoFiltrada = final

        Task {
            do {
                try await PhotoLibrarySaver.guardar(final)
                aviso = L("Guardada en tu fototeca")
            } catch {
                aviso = L("No se pudo guardar: %@", error.localizedDescription)
            }

            mostrarCaptura = false
            guardandoFoto = false

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            aviso = nil
        }
    }

    /// Recalcula la foto de la revision sin trabar el visor: espera a que el
    /// dedo deje de moverse y hace el trabajo pesado en segundo plano.
    private func programarRecalculo() {
        guard let base = foto.ultimaFoto else { return }

        let look = preset
        let ajustes = controles
        let relacion = proporcion.relacion
        let marca = sello
        let azar = semillaCaptura

        tokenAjuste += 1
        let mio = tokenAjuste

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard mio == tokenAjuste else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                let procesada = Self.componer(
                    base,
                    look: look,
                    ajustes: ajustes,
                    relacion: relacion,
                    marca: marca,
                    semilla: azar
                )

                DispatchQueue.main.async {
                    guard mio == tokenAjuste else { return }
                    fotoFiltrada = procesada
                }
            }
        }
    }

    /// Aplica el look, recorta y quema la fecha. Se usa en el visor, en la
    /// revision y al guardar, para que los tres den exactamente lo mismo.
    private static func componer(
        _ base: UIImage,
        look: FilterPreset,
        ajustes: ControlesLook,
        relacion: CGFloat?,
        marca: SelloFecha,
        semilla: UInt64
    ) -> UIImage {
        // Primero el color, despues la fecha y al final el dano de pelicula:
        // asi el grano, los rayones y la fuga tambien caen sobre la fecha y
        // se siente quemada en el negativo, no pegada encima.
        var procesada = FilterEngine.aplicar(
            look,
            a: base,
            controles: ajustes,
            semilla: semilla,
            conTextura: false
        )

        if let relacion = relacion {
            procesada = FilterEngine.recortar(procesada, relacion: relacion)
        }

        let estampada = SelloFecha.estampar(
            procesada,
            modo: marca,
            estilo: ajustes.estiloFecha,
            rotulo: look.rotulo
        )

        return FilterEngine.textura(
            look,
            a: estampada,
            controles: ajustes,
            semilla: semilla
        )
    }

    private func voltearCamara() {
        guard !video.grabando, !foto.capturando else { return }

        Task {
            await camara.voltear()
            zoomBase = camara.zoom

            aviso = camara.esFrontal ? L("Camara frontal") : L("Camara trasera")
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            aviso = nil
        }
    }
}

/// Barrita vertical de exposicion, como la del iPhone. Despues de tocar para
/// enfocar, se sube o se baja deslizando el dedo en cualquier parte del visor.
private struct BarraExposicion: View {
    let valor: Double

    private let alto: CGFloat = 116

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.yellow)

            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: alto)

                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 12, height: 1)

                Capsule()
                    .fill(Color.yellow)
                    .frame(width: 2, height: abs(desplazamiento))
                    .offset(y: desplazamiento / 2)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 22, height: 3)
                    .shadow(color: .black.opacity(0.45), radius: 2)
                    .offset(y: desplazamiento)
            }
            .frame(width: 30, height: alto)

            Text(String(format: "%+.1f", valor))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 7)
        .background(.black.opacity(0.45), in: Capsule())
        .allowsHitTesting(false)
    }

    /// 0 = centro de la barra, arriba es mas luz.
    private var progreso: CGFloat {
        CGFloat((min(max(valor, -2), 2) + 2) / 4)
    }

    private var desplazamiento: CGFloat {
        (0.5 - progreso) * alto
    }
}

/// Esquinas del marco donde deberia quedar el sujeto. Se ve como el
/// recuadro de una camara, no como una caja cualquiera.
private struct MarcoToma: Shape {
    func path(in rect: CGRect) -> Path {
        let largo = min(min(rect.width, rect.height) * 0.24, 26)
        var camino = Path()

        // Arriba izquierda.
        camino.move(to: CGPoint(x: rect.minX, y: rect.minY + largo))
        camino.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        camino.addLine(to: CGPoint(x: rect.minX + largo, y: rect.minY))

        // Arriba derecha.
        camino.move(to: CGPoint(x: rect.maxX - largo, y: rect.minY))
        camino.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        camino.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + largo))

        // Abajo derecha.
        camino.move(to: CGPoint(x: rect.maxX, y: rect.maxY - largo))
        camino.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        camino.addLine(to: CGPoint(x: rect.maxX - largo, y: rect.maxY))

        // Abajo izquierda.
        camino.move(to: CGPoint(x: rect.minX + largo, y: rect.maxY))
        camino.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        camino.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - largo))

        return camino
    }
}

/// Cuadro amarillo que marca donde enfocaste.
private struct FocusRing: View {
    @State private var escala: CGFloat = 1.5

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color.yellow, lineWidth: 1.6)
            .frame(width: 74, height: 74)
            .scaleEffect(escala)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) {
                    escala = 1
                }
            }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
