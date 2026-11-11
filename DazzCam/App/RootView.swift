import SwiftUI

/// Pantalla principal. Paso 2: muestra la camara en vivo.
struct RootView: View {
    @StateObject private var camara = CameraSession()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camara.session)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(camara.estado == .listo ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(camara.estado.descripcion)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.bottom, 40)
            }
        }
        .task {
            await camara.arrancar()
        }
        .onDisappear {
            camara.detener()
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
