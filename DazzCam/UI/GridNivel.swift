import CoreMotion
import SwiftUI

/// Cuadricula de tercios + nivel de horizonte.
/// El nivel es UNA linea continua centrada: se inclina con el telefono
/// y se pone amarilla cuando lo tienes derecho.
struct GridNivel: View {
    /// Inclinacion del telefono en radianes. 0 = derecho.
    var angulo: Double

    /// true cuando ya esta nivelado.
    var estable: Bool

    private var color: Color {
        estable ? Color.yellow : Color.white.opacity(0.55)
    }

    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            let alto = geo.size.height
            let largo = min(ancho * 0.62, 250)
            let centro = CGPoint(x: ancho / 2, y: alto / 2)

            ZStack {
                // Lineas de tercios, exactamente a 1/3 y 2/3.
                Path { camino in
                    for i in 1...2 {
                        let x = ancho * CGFloat(i) / 3
                        camino.move(to: CGPoint(x: x, y: 0))
                        camino.addLine(to: CGPoint(x: x, y: alto))

                        let y = alto * CGFloat(i) / 3
                        camino.move(to: CGPoint(x: 0, y: y))
                        camino.addLine(to: CGPoint(x: ancho, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.22), lineWidth: 0.7)

                // Punto central para centrar el encuadre.
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 22, height: 22)
                    .position(centro)

                // Nivel: linea continua + punto, ambos giran juntos.
                ZStack {
                    Capsule()
                        .fill(color)
                        .frame(width: largo, height: 1.8)

                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                }
                .rotationEffect(.radians(-angulo))
                .position(centro)
                .animation(.linear(duration: 0.06), value: angulo)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Lee el giroscopio y calcula que tan inclinado esta el telefono.
/// Usa la gravedad (medida absoluta) en vez de la actitud relativa,
/// que era lo que hacia que la linea "bailara" sola.
@MainActor
final class Nivel: ObservableObject {
    /// Inclinacion suavizada en radianes.
    @Published private(set) var angulo: Double = 0

    /// true cuando esta dentro de la tolerancia.
    @Published private(set) var estable = false

    private let manager = CMMotionManager()
    private var suave: Double = 0
    private var hayDatos = false

    func empezar() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] movimiento, _ in
            guard let self = self, let movimiento = movimiento else { return }
            self.procesar(movimiento.gravity)
        }
    }

    func parar() {
        manager.stopDeviceMotionUpdates()
        suave = 0
        hayDatos = false
        angulo = 0
        estable = false
    }

    private func procesar(_ g: CMAcceleration) {
        // Con el telefono casi acostado (apuntando al piso) el angulo
        // lateral no significa nada: mejor no mover nada.
        guard abs(g.z) < 0.9 else { return }

        let crudo = atan2(Double(g.x), -Double(g.y))

        if !hayDatos {
            suave = crudo
            hayDatos = true
        } else {
            // Filtro suave: quita el temblor de la mano sin sentirse lento.
            suave += (crudo - suave) * 0.18
        }

        // Zona muerta: si ya esta casi derecho se pega a cero exacto.
        var valor = suave
        if abs(valor) < 0.008 {
            valor = 0
        }

        // Histéresis: entra a "nivelado" a 0.46 grados y sale a 0.8.
        if estable {
            if abs(valor) > 0.014 {
                estable = false
            }
        } else if abs(valor) < 0.008 {
            estable = true
        }

        if abs(valor - angulo) > 0.0003 {
            angulo = valor
        }
    }
}
