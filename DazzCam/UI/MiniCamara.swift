import SwiftUI

/// Dibujito de la camarita real que imita cada look.
struct MiniCamara: View {
    let familia: FamiliaCamara

    private var cuerpo: Color {
        switch familia {
        case .instantanea: return Color(white: 0.94)
        case .reflex: return Color(white: 0.20)
        case .compacta: return Color(white: 0.72)
        case .digital: return Color(red: 0.22, green: 0.26, blue: 0.33)
        }
    }

    private var franja: Color {
        switch familia {
        case .instantanea: return Color(red: 0.35, green: 0.78, blue: 1.0)
        case .reflex: return Color(red: 0.95, green: 0.75, blue: 0.2)
        case .compacta: return Color(red: 1.0, green: 0.30, blue: 0.55)
        case .digital: return Color(red: 0.45, green: 0.95, blue: 0.7)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            let alto = geo.size.height
            let lente = alto * 0.5

            ZStack {
                RoundedRectangle(cornerRadius: alto * 0.16, style: .continuous)
                    .fill(cuerpo)

                // joroba del visor en las reflex
                if familia == .reflex {
                    RoundedRectangle(cornerRadius: alto * 0.06)
                        .fill(Color(white: 0.30))
                        .frame(width: ancho * 0.34, height: alto * 0.24)
                        .position(x: ancho * 0.5, y: alto * 0.12)
                }

                // lente
                ZStack {
                    Circle().fill(Color(white: 0.08))
                    Circle().strokeBorder(Color(white: 0.6).opacity(0.6), lineWidth: 0.7)
                    Circle()
                        .fill(Color(white: 0.24))
                        .frame(width: lente * 0.5, height: lente * 0.5)
                }
                .frame(width: lente, height: lente)
                .position(x: ancho * 0.40, y: alto * 0.55)

                // flash
                RoundedRectangle(cornerRadius: alto * 0.04)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: ancho * 0.18, height: alto * 0.14)
                    .position(x: ancho * 0.80, y: alto * 0.30)

                // visor en compactas y digitales
                if familia == .compacta || familia == .digital {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: ancho * 0.16, height: alto * 0.12)
                        .position(x: ancho * 0.14, y: alto * 0.30)
                }

                // franja de color de la marca
                RoundedRectangle(cornerRadius: 1)
                    .fill(franja)
                    .frame(width: ancho * 0.9, height: max(alto * 0.06, 1))
                    .position(x: ancho * 0.5, y: alto * 0.88)
            }
            .overlay(
                RoundedRectangle(cornerRadius: alto * 0.16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.7)
            )
        }
    }
}

struct MiniCamara_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            MiniCamara(familia: .compacta).frame(width: 72, height: 52)
            MiniCamara(familia: .reflex).frame(width: 72, height: 52)
            MiniCamara(familia: .instantanea).frame(width: 72, height: 52)
            MiniCamara(familia: .digital).frame(width: 72, height: 52)
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
