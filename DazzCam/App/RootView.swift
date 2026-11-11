import SwiftUI

/// Arranque de la app. Delega todo a la pantalla de camara.
struct RootView: View {
    var body: some View {
        CameraView()
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
