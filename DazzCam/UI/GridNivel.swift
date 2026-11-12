import CoreMotion
import SwiftUI

/// Lineas de tercios y nivel de horizonte.
struct GridNivel: View {
    /// Inclinacion del telefono en radianes.
    var nivel: Double

    private var inclinado: Bool { abs(nivel) > 0.017 }

    private var color: Color {
        inclinado ? Color.white.opacity(0.55) : Color.yellow
    }

    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            let alto = geo.size.height

            ZStack {
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
                .stroke(Color.white.opacity(0.3), lineWidth: 0.8)

                HStack(spacing: 8) {
                    Capsule()
                        .fill(color)
                        .frame(width: 46, height: 2)
                    Capsule()
                        .fill(color)
                        .frame(width: 46, height: 2)
                }
                .rotationEffect(.radians(inclinado ? nivel : 0))
                .position(x: ancho / 2, y: alto / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Lee el giroscopio para saber si el telefono esta derecho.
@MainActor
final class Nivel: ObservableObject {
    @Published private(set) var roll: Double = 0

    private let manager = CMMotionManager()

    func empezar() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] movimiento, _ in
            guard let self = self, let movimiento = movimiento else { return }
            self.roll = movimiento.attitude.roll
        }
    }

    func parar() {
        manager.stopDeviceMotionUpdates()
        roll = 0
    }
}
