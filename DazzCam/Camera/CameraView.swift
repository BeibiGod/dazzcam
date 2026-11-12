import SwiftUI
import Combine
import UIKit

/// Pantalla de camara completa: visor, lentes, zoom de pellizco, enfoque,
/// temporizador, exposicion, flash, proporcion, video e IA.
struct CameraView: View {
    @StateObject private var camara = CameraSession()
    @StateObject private var foto = PhotoCapture()
    @StateObject private var vivo = LiveFilterPreview()
    @StateObject private var miniaturas = FilterThumbnails()
    @StateObject private var video = MovieRecorder()

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
    @State private var proporcion: Proporcion = .completa
    @State private var exposicion: Double = 0
    @State private var mostrarExposicion = false
    @State private var cuenta: Int?

    private var versionTexto: String {
        "v1.1 · \(FilterPreset.cantidadCamaras) cam"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                visor

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

                    HStack {
                        Spacer()
                        botonIA
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

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
                        alAbrirGaleria: { mostrarCaptura = fotoFiltrada != nil },
                        alAbrirTodas: { mostrarTodas = true }
                    )
                    .padding(.bottom, insetAbajo + 6)
                }
                .frame(width: geo.size.width)

                if mostrarCaptura, let imagen = fotoFiltrada {
                    Image(uiImage: imagen)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(Color.black)
                        .onTapGesture { mostrarCaptura = false }
                        .transition(.opacity)
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
            }
            await camara.arrancar()
        }
        .onDisappear {
            camara.detener()
        }
        .onChange(of: preset) { _, nuevo in
            vivo.preset = nuevo
            aplicarFiltroAUltima()
        }
        .onChange(of: camara.zoom) { _, nuevo in
            zoomBase = nuevo
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

            var procesada = FilterEngine.aplicar(preset, a: base)
            if let relacion = proporcion.relacion {
                procesada = FilterEngine.recortar(procesada, relacion: relacion)
            }

            fotoFiltrada = procesada
            mostrarCaptura = true

            Task {
                do {
                    try await PhotoLibrarySaver.guardar(procesada)
                    aviso = "Guardada en tu fototeca"
                } catch {
                    aviso = "No se pudo guardar: \(error.localizedDescription)"
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                aviso = nil
            }
        }
        .onReceive(vivo.$imagen) { imagen in
            guard let imagen = imagen, !miniaturas.lista else { return }
            miniaturas.generar(desde: imagen)
        }
        .sheet(isPresented: $mostrarTodas) {
            CameraPickerSheet(seleccionado: $preset, muestras: miniaturas.muestras)
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

    private var visor: some View {
        Group {
            if proporcion == .completa {
                visorBase
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                visorBase
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
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
            CameraPreviewView(session: camara.session) { puntoCamara, puntoPantalla in
                camara.enfocar(en: puntoCamara)
                mostrarAnillo(en: puntoPantalla)
            }

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
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.55), in: Capsule())

            Spacer(minLength: 4)

            if modoVivo {
                Text("\(vivo.cuadrosPorSegundo) FPS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        vivo.cuadrosPorSegundo >= 20 ? Color.green : Color.yellow,
                        in: Capsule()
                    )
            }

            Button {
                modoVivo.toggle()
            } label: {
                Text(modoVivo ? "QUITAR VIVO" : "EN VIVO")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(modoVivo ? Color.black : Color.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        modoVivo ? Color.white : Color.white.opacity(0.25),
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
        HStack(spacing: 8) {
            herramienta(
                icono: flashEncendido ? "bolt.fill" : "bolt.slash.fill",
                texto: nil,
                activo: flashEncendido
            ) {
                guard camara.tieneFlash else {
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
                icono: "sun.max.fill",
                texto: String(format: "%+.1f", exposicion),
                activo: abs(exposicion) > 0.05
            ) {
                mostrarExposicion.toggle()
            }

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

    private var barraModos: some View {
        HStack(spacing: 8) {
            ForEach(camara.lentes) { lente in
                Button {
                    camara.cambiarLente(lente)
                } label: {
                    Text(lente.etiqueta)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(camara.lente == lente ? Color.black : Color.white)
                        .frame(width: 40, height: 40)
                        .background(
                            camara.lente == lente
                                ? Color.yellow
                                : Color.black.opacity(0.5),
                            in: Circle()
                        )
                        .overlay(
                            Circle().strokeBorder(
                                Color.white.opacity(camara.lente == lente ? 0 : 0.25),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }

            if camara.zoom > 1.05 {
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

    private var botonIA: some View {
        Button {
            analizarEscena()
        } label: {
            HStack(spacing: 6) {
                if analizando {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.black)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                }

                Text(analizando ? "ANALIZANDO" : "IA")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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
                    await video.empezar(preset: preset, quitar: vivo.salida)
                }
            }
        }
    }

    private func dispararConTemporizador() {
        foto.flash = (flashEncendido && camara.tieneFlash) ? .on : .off

        let segundos = temporizador.segundos
        guard segundos > 0 else {
            foto.disparar()
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
            foto.disparar()
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

    private func aplicarFiltroAUltima() {
        guard let base = foto.ultimaFoto else { return }
        fotoFiltrada = FilterEngine.aplicar(preset, a: base)
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
