import SwiftUI

/// Arranque de la app: portada con el logo y, debajo, la camara ya lista.
struct RootView: View {
    @State private var mostrarPortada = true
    @AppStorage(Idioma.clave) private var idioma: Idioma = .es

    var body: some View {
        ZStack {
            CameraView()

            if mostrarPortada {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environment(\.locale, idioma.locale)
        .task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.easeInOut(duration: 0.4)) {
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
