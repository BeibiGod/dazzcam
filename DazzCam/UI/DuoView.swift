import PhotosUI
import SwiftUI

/// CIRCLES: toma 2 fotos o importa 2 (o una + una) y se hace una sola foto.
/// Tres flujos, mismo motor `DuoFoto`:
///   A camara + camara   B galeria + galeria   C camara + galeria (ambas).
struct DuoView: View {
    @Environment(\.dismiss) private var cerrar

    @State private var a: UIImage?
    @State private var b: UIImage?
    @State private var pickA: PhotosPickerItem?
    @State private var pickB: PhotosPickerItem?
    @State private var capturandoSlot: Int?   // 0 = slot1, 1 = slot2
    @State private var insetScale: Double = 0.45
    @State private var guardando = false
    @State private var compartir = false
    @State private var error: String?
    @State private var formato: Formato = .jpg

    enum Formato: String, CaseIterable { case jpg, png }

    private var listo: Bool { a != nil && b != nil }

    /// UN solo motor para todos los flujos; la misma salida se muestra y se
    /// guarda, asi lo exportado == lo que viste en el editor.
    private var combinada: UIImage? {
        guard let a, let b else { return nil }
        return DuoFoto.combinar(a, b, insetScale: insetScale)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("CIRCLES")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text("Dos fotos, una sola. Toma con la camara, importa de la galeria, o una + una.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        espacio(indice: 0, imagen: a, seleccion: $pickA)
                        espacio(indice: 1, imagen: b, seleccion: $pickB)
                    }
                    .padding(.horizontal, 18)

                    Button {
                        swap(&a, &b)
                    } label: {
                        Label("Cambiar orden", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(!listo)

                    // EDITAR COMPOSICION
                    VStack(alignment: .leading, spacing: 7) {
                        Text("TAMAÑO DE LA SEGUNDA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Slider(value: $insetScale, in: 0.25...0.6).tint(.white)
                    }
                    .padding(.horizontal, 18)

                    if let combinada = combinada {
                        Text("VISTA PREVIA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Image(uiImage: combinada)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Picker("Formato", selection: $formato) {
                        ForEach(Formato.allCases, id: \.self) { f in
                            Text(f.rawValue.uppercased()).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 18)

                    if let error {
                        Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 24)
                    }

                    HStack(spacing: 10) {
                        Button {
                            hacerCircles(guardar: true)
                        } label: {
                            Text(guardando ? "GUARDANDO" : "GUARDAR")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(Color.white, in: Capsule()).foregroundStyle(.black)
                        }
                        .buttonStyle(.plain).disabled(!listo || guardando)

                        Button {
                            compartir = true
                        } label: {
                            Text("COMPARTIR")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(Color.white.opacity(0.15), in: Capsule()).foregroundStyle(.white)
                        }
                        .buttonStyle(.plain).disabled(!listo || guardando)
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.vertical, 18)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("CIRCLES")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { cerrar() }.foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: pickA) { _, item in cargar(item, slot: 0) }
        .onChange(of: pickB) { _, item in cargar(item, slot: 1) }
        .fullScreenCover(isPresented: Binding(
            get: { capturandoSlot != nil },
            set: { if !$0 { capturandoSlot = nil } }
        )) {
            CameraCapture { imagen in
                if let imagen {
                    if capturandoSlot == 0 { a = imagen } else { b = imagen }
                }
                capturandoSlot = nil
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $compartir) {
            if let combinada = combinada {
                ShareSheet(items: [datosExportados(combinada)])
            }
        }
    }

    private func espacio(indice: Int, imagen: UIImage?, seleccion: Binding<PhotosPickerItem?>) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                if let imagen {
                    Image(uiImage: imagen).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "photo.badge.plus").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 6) {
                Button {
                    capturandoSlot = indice
                } label: {
                    Label("Tomar", systemImage: "camera.fill")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .buttonStyle(.bordered).tint(.white)

                PhotosPicker(selection: seleccion, matching: .images) {
                    Label("Importar", systemImage: "photo.on.rectangle")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .buttonStyle(.bordered).tint(.white)
            }
        }
    }

    private func cargar(_ item: PhotosPickerItem?, slot: Int) {
        guard let item else { return }
        Task {
            if let datos = try? await item.loadTransferable(type: Data.self),
               let imagen = UIImage(data: datos) {
                if slot == 0 { a = imagen } else { b = imagen }
            }
        }
    }

    /// GUARDAR + COMPARTIR usan la MISMA combinada renderizada (pixeles).
    private func hacerCircles(guardar: Bool) { _ = guardar
        guard let combinada = combinada else { return }
        guardando = true
        error = nil
        let salida = combinada

        let datos = datosExportados(salida)

        Task {
            do {
                // Siempre se aplica Circles a los pixeles; se entrega JPG/PNG ya renderizado.
                try await PhotoLibrarySaver.guardarDatos(datos)
            } catch {
                self.error = L("No se pudo guardar: %@", error.localizedDescription)
            }
            guardando = false
        }
    }

    private func datosExportados(_ imagen: UIImage) -> Data {
        switch formato {
        case .jpg:
            return imagen.jpegData(compressionQuality: 1.0) ?? Data()
        case .png:
            return imagen.pngData() ?? Data()
        }
    }
}
