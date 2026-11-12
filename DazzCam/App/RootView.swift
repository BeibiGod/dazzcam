import SwiftUI

/// Arranque de la app: portada con el ninja y, debajo, la camara ya lista.
struct RootView: View {
    @State private var mostrarPortada = true

    var body: some View {
        ZStack {
            CameraView()

            if mostrarPortada {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeInOut(duration: 0.45)) {
                mostrarPortada = false
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
