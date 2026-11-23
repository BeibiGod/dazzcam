import SwiftUI

/// Muestra una foto con zoom de revision: pellizca para acercar, arrastra
/// para moverte y doble toque para volver. Solo cambia lo que ves; la foto
/// que se guarda sale completa.
struct FotoZoom: View {
    let imagen: UIImage

    @State private var zoom: CGFloat = 1
    @State private var zoomGuardado: CGFloat = 1
    @State private var desplazamiento: CGSize = .zero
    @State private var desplazamientoGuardado: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let tamano = tamanoAjustado(imagen, en: geo.size)

            ZStack {
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .offset(desplazamiento)
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { valor in
                                    zoom = min(max(zoomGuardado * valor, 1), 5)
                                }
                                .onEnded { _ in
                                    zoomGuardado = zoom
                                    if zoom <= 1.01 {
                                        restablecer()
                                    } else {
                                        limitar(tamano: tamano, caja: geo.size)
                                    }
                                },
                            DragGesture()
                                .onChanged { valor in
                                    guard zoom > 1.01 else { return }
                                    desplazamiento = CGSize(
                                        width: desplazamientoGuardado.width
                                            + valor.translation.width,
                                        height: desplazamientoGuardado.height
                                            + valor.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    desplazamientoGuardado = desplazamiento
                                    limitar(tamano: tamano, caja: geo.size)
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        if zoom > 1.01 {
                            restablecer()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                zoom = 2.5
                                zoomGuardado = 2.5
                            }
                        }
                    }

                // Chincheta del zoom: solo aparece cuando estas acercado y
                // se toca para volver a 1x.
                if zoom > 1.01 {
                    VStack {
                        HStack {
                            Button {
                                restablecer()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(String(format: "%.1fx", zoom))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .monospacedDigit()
                                }
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white, in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }

                        Spacer()
                    }
                    .padding(10)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    // MARK: - Cuentas

    /// Tamano con el que la foto entra en la caja, respetando su proporcion.
    private func tamanoAjustado(_ imagen: UIImage, en caja: CGSize) -> CGSize {
        guard caja.width > 0, caja.height > 0, imagen.size.height > 0 else { return caja }

        let relacion = imagen.size.width / imagen.size.height
        let relacionCaja = caja.width / caja.height

        if relacion > relacionCaja {
            return CGSize(width: caja.width, height: caja.width / relacion)
        }
        return CGSize(width: caja.height * relacion, height: caja.height)
    }

    /// Que no se pueda arrastrar la foto fuera de la pantalla.
    private func limitar(tamano: CGSize, caja: CGSize) {
        let maxX = max((tamano.width * zoom - caja.width) / 2, 0)
        let maxY = max((tamano.height * zoom - caja.height) / 2, 0)

        desplazamiento = CGSize(
            width: min(max(desplazamiento.width, -maxX), maxX),
            height: min(max(desplazamiento.height, -maxY), maxY)
        )
        desplazamientoGuardado = desplazamiento
    }

    private func restablecer() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoom = 1
            zoomGuardado = 1
            desplazamiento = .zero
            desplazamientoGuardado = .zero
        }
    }
}
