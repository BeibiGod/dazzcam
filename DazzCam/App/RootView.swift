import SwiftUI

/// Pantalla base. Su unico trabajo es demostrar que el proyecto compila
/// y que la app arranca en el telefono. Se reemplaza por la camara
/// cuando la base este en verde.
struct RootView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(.white)

                Text("DazzCam")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Base compilando")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
