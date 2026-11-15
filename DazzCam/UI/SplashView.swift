import SwiftUI

/// Portada de arranque: solo el logo, sin texto. Fina y al centro.
struct SplashView: View {
    @State private var aparecer = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("LogoNinja")
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .opacity(aparecer ? 1 : 0)
                .scaleEffect(aparecer ? 1 : 0.96)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
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
