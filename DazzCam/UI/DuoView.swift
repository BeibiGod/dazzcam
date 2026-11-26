import PhotosUI
import SwiftUI

/// DUO: toma 2 fotos o importa 2 y se hace una sola (dos cuadritos juntos).
struct DuoView: View {
    @Environment(\.dismiss) private var cerrar

    @State private var a: UIImage?
    @State private var b: UIImage?
    @State private var pickA: PhotosPickerItem?
    @State private var pickB: PhotosPickerItem?
    @State private var guardando = false
    @State private var error: String?

    private var listo: Bool { a != nil && b != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Dos cuadritos se vuelven una sola foto.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))

                    HStack(spacing: 12) {
                        espacio(titulo: "1", imagen: a, seleccion: $pickA)
                        espacio(titulo: "2", imagen: b, seleccion: $pickB)
                    }
                    .padding(.horizontal, 18)

                    Text("Toma dos fotos con Beibi Cam y guárdalas, o importa dos de tu fototeca.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let combinada = listo ? DuoFoto.combinar(a!, b!, lado: 240) : nil {
                        Text("VISTA PREVIA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Image(uiImage: combinada)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        hacerDuo()
                    } label: {
                        HStack(spacing: 8) {
                            if guardando { ProgressView().tint(.black) }
                            Text(guardando ? "GUARDANDO" : "HACER DUO")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!listo || guardando)
                    .opacity(listo ? 1 : 0.4)
                    .padding(.horizontal, 18)
                }
                .padding(.vertical, 18)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("DUO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { cerrar() }.foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: pickA) { _, item in cargar(item) { a = $0 } }
        .onChange(of: pickB) { _, item in cargar(item) { b = $0 } }
    }

    private func espacio(
        titulo: String,
        imagen: UIImage?,
        seleccion: Binding<PhotosPickerItem?>
    ) -> some View {
        PhotosPicker(selection: seleccion, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)

                if let imagen {
                    Image(uiImage: imagen)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 20, weight: .semibold))
                        Text(titulo)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private func cargar(_ item: PhotosPickerItem?, _ poner: @escaping (UIImage?) -> Void) {
        guard let item else { poner(nil); return }
        Task {
            if let datos = try? await item.loadTransferable(type: Data.self),
               let imagen = UIImage(data: datos) {
                poner(imagen)
            }
        }
    }

    private func hacerDuo() {
        guard let a, let b else { return }
        guardando = true
        error = nil
        let combinada = DuoFoto.combinar(a, b)

        Task {
            do {
                try await PhotoLibrarySaver.guardar(combinada)
                cerrar()
            } catch {
                self.error = L("No se pudo guardar: %@", error.localizedDescription)
            }
            guardando = false
        }
    }
}
