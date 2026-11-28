import PhotosUI
import SwiftUI

/// CIRCLES. Dos opciones independientes + UN editor + UN motor `DuoFoto`.
struct DuoView: View {
    var preset: FilterPreset = .original
    var controles: ControlesLook = ControlesLook()
    var sello: SelloFecha = .apagado
    var proporcion: Proporcion = .dieciseisNueve
    @Environment(\.dismiss) private var cerrar

    enum Ruta: Identifiable { case camara, editor; var id: String { "\(self)" } }

    @State private var ruta: Ruta?
    @State private var a: UIImage?
    @State private var b: UIImage?
    @State private var galleryPicks: [PhotosPickerItem] = []
    @State private var showGallery = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("CIRCLES")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                Text("Doble exposicion. Dos fotos, una sola.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()

                // OPCION A: TOMAR FOTO
                Button {
                    ruta = .camara
                } label: {
                    opcion(titulo: "TOMAR FOTO", sub: "Camara real, disparo grande", icono: "camera.fill")
                }
                .buttonStyle(.plain)

                // OPCION B: IMPORTAR FOTOS
                PhotosPicker(selection: $galleryPicks, maxSelectionCount: 2, matching: .images) {
                    opcion(titulo: "IMPORTAR FOTOS", sub: "Elige exactamente dos de la galeria", icono: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("CIRCLES")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Listo") { cerrar() }.foregroundStyle(.white) }
            }
        }
        .preferredColorScheme(.dark)
                .sheet(isPresented: $showGallery) {
            CirclesGalleryScreen(a: a, b: b) { x, y in
                a = x; b = y; showGallery = false; ruta = .editor
            }
        }
        .onChange(of: galleryPicks) { _, picks in cargarGaleria(picks) }
        .fullScreenCover(isPresented: Binding(get: { ruta == .camara }, set: { if !$0 { ruta = nil } })) {
            CirclesCameraView { imgs in
                if imgs.count >= 2 {
                    a = imgs[0]; b = imgs[1]; ruta = .editor
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { ruta == .editor }, set: { if !$0 { ruta = nil } })) {
            if let a, let b {
                CirclesEditor(inicialA: a, inicialB: b, proporcionInicial: proporcion) { cerrar() }
            }
        }
    }

    private func opcion(titulo: String, sub: String, icono: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icono).font(.system(size: 24, weight: .semibold)).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.system(size: 13, weight: .bold, design: .monospaced))
                Text(sub).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func cargarGaleria(_ picks: [PhotosPickerItem]) {
        guard picks.count == 2 else { return }
        Task {
            var imgs: [UIImage] = []
            for p in picks {
                if let d = try? await p.loadTransferable(type: Data.self), let i = UIImage(data: d) { imgs.append(i) }
            }
            if imgs.count == 2 {
                a = imgs[0]; b = imgs[1]
                showGallery = true
                galleryPicks = []
            }
        }
    }

    private func abrirEditor() { ruta = .editor }
}
