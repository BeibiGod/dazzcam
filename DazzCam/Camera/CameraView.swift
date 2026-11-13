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
    @State private var analizando = false
    @State private var modo: ModoCaptura = .foto
    @State private var vivoAntesDeGrabar = true

    @State private var zoomBase: CGFloat = 1
    @State private var flashEncendido = false
    @State private var temporizador: Temporizador = .apagado
    @State private var proporcion: Proporcion = .dieciseisNueve
    @State private var exposicion: Double = 0
    @State private var mostrarExposicion = false
    @State private var cuenta: Int?
    @State private var mostrarCuadricula = true
    @State private var sello: SelloFecha = .dazz
    @State private var destello: Double = 0
    @State private var mostrarImportar = false
    @State private var fotoElegida: PhotosPickerItem?
    @State private var fotoImportada: UIImage?
    @State private var mostrarEditor = false
    @State private var videoImportado: URL?
    @State private var mostrarEditorVideo = false
    @State private var controles = ControlesLook()
    @State private var mostrarAjustes = false
    @State private var puntoExposicion: CGPoint?
    @State private var barraExposicionVisible = false
    @State private var tokenExposicion = 0
    @State private var tokenAjuste = 0
    @State private var guardandoFoto = false

    private var versionTexto: String {
        "v1.10.1 · \(FilterPreset.cantidadCamaras) cam"
    }

    private var textoVivo: String {
        guard modoVivo else { return "VIVO" }
        return vivo.cuadrosPorSegundo > 0 ? "VIVO \(vivo.cuadrosPorSegundo)" : "VIVO"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                visor(geo)

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

                    if sello.encendido {
                        HStack {
                            Spacer()

                            TimelineView(.periodic(from: .now, by: 1)) { contexto in
                                Text(SelloFecha.texto(sello, fecha: contexto.date))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.12))
                                    .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 1)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                    }

                    barraHerramientas
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)

                    if mostrarExposicion {
                        controlExposicion
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                    }

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

                    barraModos
                        .padding(.bottom, 8)

                    CameraBar(
                        seleccionado: $preset,
                        muestras: miniaturas.muestras,
                        capturando: foto.capturando,
                        grabando: video.grabando,
                        procesando: video.procesando,
                        segundos: video.segundos,
                        alDisparar: accionDeDisparo,
                        alImportar: { mostrarImportar = true },
                        alAbrirTodas: { mostrarTodas = true }
                    )
                    .padding(.bottom, insetAbajo + 6)
                }
                .frame(width: geo.size.width)

                if mostrarCaptura, let imagen = fotoFiltrada {
                    ZStack {
                        Color.black

                        Image(uiImage: imagen)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)

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
            }
            await camara.arrancar()
            camara.ponerZoom(1)
            zoomBase = camara.zoom
            if mostrarCuadricula {
                nivel.empezar()
            }
        }
        .onDisappear {
            nivel.parar()
            camara.detener()
        }
        .onChange(of: fase) { _, nueva in
            // Al volver a entrar a la app siempre arranca en 1x y 16:9.
            guard nueva == .active else { return }
            camara.ponerZoom(1)
            zoomBase = camara.zoom
            proporcion = .dieciseisNueve
        }
        .onChange(of: preset) { _, nuevo in
            vivo.preset = nuevo
            if mostrarCaptura {
                programarRecalculo()
            }
        }
        .onChange(of: controles) { _, nuevo in
            vivo.controles = nuevo
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
        .onChange(of: foto.capturas) { _, _ in
            guard let base = foto.ultimaFoto else { return }

            if !miniaturas.lista {
                miniaturas.generar(desde: base)
            }

            fotoFiltrada = Self.componer(
                base,
                look: preset,
                ajustes: controles,
                relacion: proporcion.relacion,
                marca: sello
            )
            mostrarCaptura = true
        }
        .onReceive(vivo.$imagen) { imagen in
            guard let imagen = imagen, !miniaturas.lista else { return }
            miniaturas.generar(desde: imagen)
        }
        .sheet(isPresented: $mostrarTodas) {
            CameraPickerSheet(seleccionado: $preset, muestras: miniaturas.muestras)
        }
        .sheet(isPresented: $mostrarAjustes) {
            AjustesLookView(controles: $controles, preset: preset)
                .presentationDetents([.height(470)])
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
                        aviso = "No pude abrir ese video"
                    }
                } else if let datos = try? await item.loadTransferable(type: Data.self),
                          let imagen = UIImage(data: datos) {
                    fotoImportada = imagen
                    mostrarEditor = true
                } else {
                    aviso = "No pude abrir esa foto"
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
                    aviso = "Video guardado con \(elegido.nombre)"
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
                        aviso = "Copia guardada con \(elegido.nombre)"
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

            if let punto = puntoExposicion, barraExposicionVisible {
                BarraExposicion(
                    valor: Binding(
                        get: { exposicion },
                        set: { nuevo in
                            exposicion = nuevo
                            camara.fijarExposicion(Float(nuevo))
                        }
                    )
                )
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

    // MARK: - Encabezado

    private var cabecera: some View {
        HStack(spacing: 8) {
            Text(versionTexto)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.black.opacity(0.45), in: Capsule())

            Spacer(minLength: 4)

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
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Herramientas

    private var barraHerramientas: some View {
        HStack(spacing: 6) {
            herramienta(
                icono: flashEncendido ? "bolt.fill" : "bolt.slash.fill",
                texto: (camara.esFrontal && flashEncendido) ? "PANT" : nil,
                activo: flashEncendido
            ) {
                guard camara.tieneFlash || camara.esFrontal else {
                    aviso = "Esta lente no tiene flash"
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

            herramienta(
                icono: "crop",
                texto: proporcion.etiqueta,
                activo: proporcion == .dieciseisNueve
            ) {
                proporcion = proporcion.alterna
            }

            herramienta(
                icono: "square.grid.3x3",
                texto: nil,
                activo: mostrarCuadricula
            ) {
                mostrarCuadricula.toggle()
                if mostrarCuadricula {
                    nivel.empezar()
                } else {
                    nivel.parar()
                }
            }

            herramienta(
                icono: "sun.max.fill",
                texto: abs(exposicion) > 0.05 ? String(format: "%+.1f", exposicion) : nil,
                activo: abs(exposicion) > 0.05
            ) {
                mostrarExposicion.toggle()
            }

            menuFecha

            // En video no hay revision despues de grabar, asi que el look se
            // ajusta antes. En foto se ajusta despues de disparar.
            if modo == .video {
                herramienta(
                    icono: "slider.horizontal.3",
                    texto: controles.automatico ? nil : "LOOK",
                    activo: !controles.automatico
                ) {
                    mostrarAjustes = true
                }
            }

            herramientaIA

            Spacer()
        }
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

    /// Menu del sello: fecha tipo DazzCam o fecha del iPhone.
    private var menuFecha: some View {
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
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))

                if sello.encendido {
                    Text(sello.etiqueta)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
            }
            .foregroundStyle(sello.encendido ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                sello.encendido ? Color.yellow : Color.black.opacity(0.5),
                in: Capsule()
            )
        }
        .fixedSize()
    }

    private var controlExposicion: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.min")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))

            Slider(value: $exposicion, in: -2...2, step: 0.1)
                .tint(.yellow)
                .onChange(of: exposicion) { _, nuevo in
                    camara.fijarExposicion(Float(nuevo))
                }

            Image(systemName: "sun.max")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5), in: Capsule())
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

    private var barraModos: some View {
        HStack(spacing: 8) {
            ForEach(camara.lentes) { lente in
                Button {
                    camara.irA(lente)
                    zoomBase = camara.zoom
                } label: {
                    Text(lente.etiqueta)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(lenteActiva(lente) ? Color.black : Color.white)
                        .frame(width: 40, height: 40)
                        .background(
                            lenteActiva(lente)
                                ? Color.yellow
                                : Color.black.opacity(0.5),
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
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .fixedSize()
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(ModoCaptura.allCases) { opcion in
                    Button {
                        guard !video.grabando else { return }
                        modo = opcion
                    } label: {
                        Text(opcion.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(modo == opcion ? Color.black : Color.white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                modo == opcion ? Color.white : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.5), in: Capsule())
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Boton IA

    private var herramientaIA: some View {
        Button {
            analizarEscena()
        } label: {
            HStack(spacing: 5) {
                if analizando {
                    ProgressView()
                        .scaleEffect(0.55)
                        .tint(.black)
                        .frame(width: 13, height: 13)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text("IA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 1.0, green: 0.30, blue: 0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(analizando)
        .fixedSize()
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
                Task {
                    await video.empezar(
                        preset: preset,
                        controles: controles,
                        sello: sello,
                        quitar: vivo.salida
                    )
                }
            }
        }
    }

    private func dispararConTemporizador() {
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

    private func analizarEscena() {
        guard let imagen = vivo.imagen ?? foto.ultimaFoto else {
            aviso = "La camara todavia no tiene imagen"
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                aviso = nil
            }
            return
        }

        analizando = true

        Task {
            let resultado = await AestheticAnalyzer.analizar(imagen)
            analizando = false

            guard let resultado = resultado else {
                aviso = "No pude analizar la escena"
                return
            }

            analisis = resultado
            mostrarIA = true
        }
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
        tokenExposicion += 1
        let mio = tokenExposicion

        withAnimation(.easeOut(duration: 0.18)) {
            barraExposicionVisible = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
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
            marca: sello
        )
        fotoFiltrada = final

        Task {
            do {
                try await PhotoLibrarySaver.guardar(final)
                aviso = "Guardada en tu fototeca"
            } catch {
                aviso = "No se pudo guardar: \(error.localizedDescription)"
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
                    marca: marca
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
        marca: SelloFecha
    ) -> UIImage {
        var procesada = FilterEngine.aplicar(look, a: base, controles: ajustes)

        if let relacion = relacion {
            procesada = FilterEngine.recortar(procesada, relacion: relacion)
        }

        return SelloFecha.estampar(procesada, modo: marca)
    }

    private func voltearCamara() {
        guard !video.grabando, !foto.capturando else { return }

        Task {
            await camara.voltear()
            zoomBase = camara.zoom

            aviso = camara.esFrontal ? "Camara frontal" : "Camara trasera"
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            aviso = nil
        }
    }
}

/// Barrita vertical de exposicion que sale al tocar para enfocar.
private struct BarraExposicion: View {
    @Binding var valor: Double

    private let alto: CGFloat = 112

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.85))

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 3, height: alto)

                Capsule()
                    .fill(Color.yellow)
                    .frame(width: 3, height: max(4, progreso * alto))

                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(y: -(progreso * alto) + 7.5)
            }
            .frame(width: 26, height: alto)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesto in
                        let y = min(max(gesto.location.y, 0), alto)
                        let t = 1 - Double(y / alto)
                        valor = -1.5 + t * 3.0
                    }
            )

            Image(systemName: "sun.min")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 5)
        .background(.black.opacity(0.45), in: Capsule())
    }

    private var progreso: CGFloat {
        CGFloat((min(max(valor, -1.5), 1.5) + 1.5) / 3.0)
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
