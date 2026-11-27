import SwiftUI

/// Editor Circles (doble exposicion), UNO solo para ambos flujos.
struct CirclesEditor: View {
    let inicialA: UIImage
    let inicialB: UIImage
    var onDone: () -> Void

    @State private var comp = CirclesComposition()
    @State private var swapOrder = false
    @State private var formato: Formato = .jpg
    @State private var guardando = false
    @State private var compartir = false
    @State private var error: String?

    enum Formato: String, CaseIterable { case jpg, png }

    private var a: UIImage { swapOrder ? inicialB : inicialA }
    private var b: UIImage { swapOrder ? inicialA : inicialB }

    private var combinada: UIImage {
        var c = comp
        c.swapOrder = swapOrder
        return DuoFoto.combinar(inicialA, inicialB, composicion: c)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Image(uiImage: combinada)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 14)

                    Button { swapOrder.toggle() } label: {
                        Label("Cambiar orden", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(.bordered).tint(.white)

                    slider("POSICION X 2a", value: $comp.offset2.x, range: -0.5...0.5)
                    slider("POSICION Y 2a", value: offsetY, range: -0.5...0.5)
                    slider("TAMANO 2a", value: $comp.scale2, range: 0.3...1.5)
                    slider("INTENSIDAD", value: $comp.intensity, range: 0...1)

                    Picker("Mezcla", selection: $comp.blend) {
                        ForEach(CirclesComposition.Blend.allCases) { m in Text(m.nombre).tag(m) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 14)

                    Toggle("Mascara de luminancia", isOn: $comp.luminanceMask).tint(.white).padding(.horizontal, 18)

                    Picker("Formato", selection: $formato) {
                        ForEach(Formato.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 18)

                    if let error { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 24) }

                    HStack(spacing: 10) {
                        Button { exportar(guardar: true) } label: {
                            Text(guardando ? "GUARDANDO" : "GUARDAR").font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity).padding(.vertical, 13).background(Color.white, in: Capsule()).foregroundStyle(.black)
                        }
                        .buttonStyle(.plain).disabled(guardando)

                        Button { compartir = true } label: {
                            Text("COMPARTIR").font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity).padding(.vertical, 13).background(Color.white.opacity(0.15), in: Capsule()).foregroundStyle(.white)
                        }
                        .buttonStyle(.plain).disabled(guardando)
                    }
                    .padding(.horizontal, 18).padding(.bottom, 18)
                }
                .padding(.top, 14)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("CIRCLES")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Listo") { onDone() }.foregroundStyle(.white) }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $compartir) {
            ShareSheet(items: [datosExportados(combinada)])
        }
    }

    private var offsetY: Binding<CGFloat> {
        Binding(get: { comp.offset2.y }, set: { comp.offset2.y = $0 })
    }

    private func slider(_ titulo: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            Slider(value: value, in: range).tint(.white)
        }
        .padding(.horizontal, 18)
    }

    private func exportar(guardar: Bool) {
        guardando = true; error = nil
        let img = combinada
        let datos = datosExportados(img)
        Task {
            do { try await PhotoLibrarySaver.guardarDatos(datos) }
            catch { self.error = L("No se pudo guardar: %@", error.localizedDescription) }
            guardando = false
        }
    }

    private func datosExportados(_ imagen: UIImage) -> Data {
        switch formato {
        case .jpg: return imagen.jpegData(compressionQuality: 1.0) ?? Data()
        case .png: return imagen.pngData() ?? Data()
        }
    }
}
