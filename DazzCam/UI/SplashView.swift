import SwiftUI

/// Portada de arranque: el ninja y el nombre de la app.
struct SplashView: View {
    @State private var aparecer = false

    private let rosa = Color(red: 1.0, green: 0.30, blue: 0.55)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LogoNinja")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 164, height: 164)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: rosa.opacity(0.35), radius: 30)

                Text("BEIBI CAM")
                    .font(.system(size: 21, weight: .heavy, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(.white)

                Text("camara vintage")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .scaleEffect(aparecer ? 1 : 0.94)
            .opacity(aparecer ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                aparecer = true
            }
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
