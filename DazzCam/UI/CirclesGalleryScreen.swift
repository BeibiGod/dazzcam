import SwiftUI

/// Flujo GALERIA: muestra las dos elegidas, permite reordenar, continuar.
struct CirclesGalleryScreen: View {
    let a: UIImage?
    let b: UIImage?
    var onContinue: (UIImage, UIImage) -> Void

    @State private var swapped = false
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("ELIGE EL ORDEN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 12) {
                    tarjeta(imagen: swapped ? b : a, titulo: "1")
                    tarjeta(imagen: swapped ? a : b, titulo: "2")
                }
                .padding(.horizontal, 18)

                Button {
                    swapped.toggle()
                } label: {
                    Label("Cambiar orden", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .buttonStyle(.bordered).tint(.white)

                Spacer()

                Button {
                    if let a, let b {
                        let x = swapped ? b : a
                        let y = swapped ? a : b
                        onContinue(x, y)
                    }
                } label: {
                    Text("CONTINUAR")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.white, in: Capsule()).foregroundStyle(.black)
                }
                .buttonStyle(.plain).padding(.horizontal, 18).padding(.bottom, 18)
            }
            .padding(.top, 18)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("DOS FOTOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Cancelar") { cerrar() }.foregroundStyle(.white) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func tarjeta(imagen: UIImage?, titulo: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08))
                if let imagen {
                    Image(uiImage: imagen).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            Text(titulo).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
        }
    }
}
