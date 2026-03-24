import SwiftUI

// MARK: - Scan Corner Bracket Shape

struct ScanCornerBracket: Shape {
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    let corner: Corner
    let armLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let t: CGFloat = 2

        switch corner {
        case .topLeft:
            path.addRect(CGRect(x: 0, y: 0, width: t, height: armLength))
            path.addRect(CGRect(x: 0, y: 0, width: armLength, height: t))
        case .topRight:
            path.addRect(CGRect(x: armLength - t, y: 0, width: t, height: armLength))
            path.addRect(CGRect(x: 0, y: 0, width: armLength, height: t))
        case .bottomLeft:
            path.addRect(CGRect(x: 0, y: 0, width: t, height: armLength))
            path.addRect(CGRect(x: 0, y: armLength - t, width: armLength, height: t))
        case .bottomRight:
            path.addRect(CGRect(x: armLength - t, y: 0, width: t, height: armLength))
            path.addRect(CGRect(x: 0, y: armLength - t, width: armLength, height: t))
        }

        return path
    }
}

// MARK: - Corner Bracket View

struct CornerBracket: View {
    let corner: ScanCornerBracket.Corner
    var armLength: CGFloat = 22
    var color: Color = .white.opacity(0.55)

    var body: some View {
        ScanCornerBracket(corner: corner, armLength: armLength)
            .fill(color)
            .frame(width: armLength, height: armLength)
    }
}

// MARK: - Main Logo View

struct PantryPalLogo: View {
    private let iconSize: CGFloat = 280
    private let cornerRadius: CGFloat = 62
    private let bracketInset: CGFloat = 22
    private let bracketVertical: CGFloat = 80

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#41B3F0"), location: 0.00),
                            .init(color: Color(hex: "#1976D2"), location: 0.30),
                            .init(color: Color(hex: "#1251B3"), location: 0.60),
                            .init(color: Color(hex: "#0A3A8C"), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.1, y: 0.0),
                        endPoint: UnitPoint(x: 0.9, y: 1.0)
                    )
                )

            RadialGradient(colors: [Color(hex: "#5BB8F5").opacity(1), .clear],
                           center: UnitPoint(x: 0.25, y: 0.15),
                           startRadius: 0, endRadius: iconSize * 0.5)

            RadialGradient(colors: [Color(hex: "#0C4EA8").opacity(1), .clear],
                           center: UnitPoint(x: 0.80, y: 0.85),
                           startRadius: 0, endRadius: iconSize * 0.55)

            RadialGradient(colors: [.white.opacity(0.18), .clear],
                           center: UnitPoint(x: 0.50, y: 0.20),
                           startRadius: 0, endRadius: iconSize * 0.48)

            RadialGradient(colors: [.white.opacity(0.07), .clear],
                           center: UnitPoint(x: 0.15, y: 0.50),
                           startRadius: 0, endRadius: iconSize * 0.28)

            RadialGradient(colors: [.white.opacity(0.05), .clear],
                           center: UnitPoint(x: 0.85, y: 0.60),
                           startRadius: 0, endRadius: iconSize * 0.24)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let arm: CGFloat = 22
                let inset: CGFloat = bracketInset
                let vOff: CGFloat = bracketVertical

                Group {
                    CornerBracket(corner: .topLeft,     armLength: arm)
                        .position(x: inset + arm / 2,     y: vOff + arm / 2)
                    CornerBracket(corner: .topRight,    armLength: arm)
                        .position(x: w - inset - arm / 2, y: vOff + arm / 2)
                    CornerBracket(corner: .bottomLeft,  armLength: arm)
                        .position(x: inset + arm / 2,     y: h - vOff - arm / 2)
                    CornerBracket(corner: .bottomRight, armLength: arm)
                        .position(x: w - inset - arm / 2, y: h - vOff - arm / 2)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("P")
                    .font(.system(size: 70, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.97))
                    .tracking(-2.5)
                Text("antry")
                    .font(.system(size: 35, weight: .light, design: .default))
                    .foregroundColor(.white.opacity(0.82))
                    .tracking(-0.5)
                Spacer().frame(width: 14)
                Text("P")
                    .font(.system(size: 70, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.97))
                    .tracking(-2.5)
                Text("al")
                    .font(.system(size: 35, weight: .light, design: .default))
                    .foregroundColor(.white.opacity(0.82))
                    .tracking(-0.5)
            }
            .shadow(color: .white.opacity(0.4), radius: 0, x: 0, y: 1)
            .shadow(color: Color(hex: "#08288C").opacity(0.5), radius: 10, x: 0, y: 2)
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#08328C").opacity(0.6), radius: 50, x: 0, y: 40)
        .shadow(color: Color(hex: "#08328C").opacity(0.4), radius: 16, x: 0, y: 12)
    }
}

// MARK: - Icon Exporter (saves 1024x1024 PNG to Photos)

struct IconExporterView: View {
    @State private var exported = false

    var body: some View {
        VStack(spacing: 24) {
            PantryPalLogo()
                .scaleEffect(1.2)

            Button(exported ? "Saved to Photos ✓" : "Export as App Icon") {
                exportIcon()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(exported)
        }
        .padding()
    }

    @MainActor
    private func exportIcon() {
        let logo = PantryPalLogo().frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: logo)
        renderer.scale = 1.0
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        exported = true
    }
}

#Preview {
    ZStack {
        Color(hex: "#F0F0F5").ignoresSafeArea()
        PantryPalLogo()
    }
}
