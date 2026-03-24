import SwiftUI

struct BreadyIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let sx = w / 230
            let sy = h / 230
            func s(_ v: CGFloat) -> CGFloat { v * sx }
            func sv(_ v: CGFloat) -> CGFloat { v * sy }

            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: "#16172a"), Color(hex: "#09090f")]),
                    startPoint: .init(x: w * 0.3, y: 0),
                    endPoint: .init(x: w * 0.7, y: h)
                )
            )

            // Ground glow
            let glowCenter = CGPoint(x: s(115), y: sv(205))
            context.fill(
                Ellipse().path(in: CGRect(x: glowCenter.x - s(78), y: glowCenter.y - sv(16),
                                          width: s(156), height: sv(32))),
                with: .color(Color(hex: "#a0500f").opacity(0.07))
            )

            // Base rect (side crust)
            let basePath = Path(roundedRect:
                CGRect(x: s(30), y: sv(126), width: s(170), height: sv(66)),
                cornerRadius: s(22)
            )
            context.fill(basePath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(hex: "#9e4e0e"), location: 0.0),
                    .init(color: Color(hex: "#773808"), location: 0.55),
                    .init(color: Color(hex: "#572806"), location: 1.0),
                ]),
                startPoint: CGPoint(x: s(115), y: sv(126)),
                endPoint: CGPoint(x: s(115), y: sv(192))
            ))

            // Dome
            var domePath = Path()
            domePath.move(to: CGPoint(x: s(40), y: sv(138)))
            domePath.addQuadCurve(
                to: CGPoint(x: s(190), y: sv(138)),
                control: CGPoint(x: s(115), y: sv(38))
            )
            context.fill(domePath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(hex: "#dd8528"), location: 0.0),
                    .init(color: Color(hex: "#bc5e14"), location: 0.28),
                    .init(color: Color(hex: "#923a09"), location: 0.68),
                    .init(color: Color(hex: "#6a2706"), location: 1.0),
                ]),
                startPoint: CGPoint(x: s(40) + s(150) * 0.12, y: sv(38)),
                endPoint: CGPoint(x: s(40) + s(150) * 0.88, y: sv(138))
            ))

            // Dome sheen
            var sheenPath = Path()
            sheenPath.move(to: CGPoint(x: s(40), y: sv(140)))
            sheenPath.addQuadCurve(
                to: CGPoint(x: s(190), y: sv(140)),
                control: CGPoint(x: s(115), y: sv(40))
            )
            sheenPath.addLine(to: CGPoint(x: s(190), y: sv(148)))
            sheenPath.addQuadCurve(
                to: CGPoint(x: s(40), y: sv(148)),
                control: CGPoint(x: s(115), y: sv(48))
            )
            sheenPath.closeSubpath()
            context.fill(sheenPath, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0)]),
                startPoint: CGPoint(x: s(40) + s(150)*0.18, y: sv(38)),
                endPoint: CGPoint(x: s(40) + s(150)*0.52, y: sv(148))
            ))

            // Score line on dome
            var scorePath = Path()
            scorePath.move(to: CGPoint(x: s(58), y: sv(134)))
            scorePath.addQuadCurve(
                to: CGPoint(x: s(172), y: sv(134)),
                control: CGPoint(x: s(115), y: sv(62))
            )
            context.stroke(scorePath,
                with: .color(Color.white.opacity(0.08)),
                style: StrokeStyle(lineWidth: s(1.5), lineCap: .round)
            )

            // Crumb fill
            let crumbRect = CGRect(x: s(36), y: sv(140), width: s(158), height: sv(46))
            context.fill(
                Path(roundedRect: crumbRect, cornerRadius: s(16)),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: "#eaba64"), Color(hex: "#c98c32")]),
                    startPoint: CGPoint(x: s(115), y: sv(140)),
                    endPoint: CGPoint(x: s(115), y: sv(186))
                )
            )
            context.fill(
                Path(roundedRect: CGRect(x: s(36), y: sv(140), width: s(158), height: sv(2.5)), cornerRadius: s(1)),
                with: .color(Color.black.opacity(0.12))
            )
            context.fill(
                Path(roundedRect: CGRect(x: s(36), y: sv(183), width: s(158), height: sv(2)), cornerRadius: s(1)),
                with: .color(Color.black.opacity(0.17))
            )

            // Eyes
            let eyeRadius = CGSize(width: s(21), height: sv(20))
            let leftEyeCenter  = CGPoint(x: s(84),  y: sv(106))
            let rightEyeCenter = CGPoint(x: s(146), y: sv(106))

            func drawEye(center: CGPoint) {
                let eyeRect = CGRect(
                    x: center.x - eyeRadius.width,
                    y: center.y - eyeRadius.height,
                    width: eyeRadius.width * 2,
                    height: eyeRadius.height * 2
                )
                let eyePath = Path(ellipseIn: eyeRect)
                context.fill(eyePath, with: .color(Color(hex: "#f5f3ee")))
                context.drawLayer { ctx in
                    ctx.clip(to: eyePath)
                    ctx.fill(Path(CGRect(
                        x: center.x,
                        y: center.y - eyeRadius.height - 1,
                        width: eyeRadius.width + 1,
                        height: eyeRadius.height * 2 + 2
                    )), with: .color(Color(hex: "#0c0c0f")))
                }
                context.stroke(eyePath,
                    with: .color(Color(red: 0.24, green: 0.16, blue: 0.06).opacity(0.22)),
                    lineWidth: s(0.75)
                )
            }

            drawEye(center: leftEyeCenter)
            drawEye(center: rightEyeCenter)
        }
        .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
    }
}

struct BreadyIconView: View {
    let size: CGFloat

    var body: some View {
        BreadyIcon()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * (52/230), style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
            .shadow(color: .black.opacity(0.22), radius: 50, x: 0, y: 20)
    }
}

#Preview {
    ZStack {
        Color(hex: "#1a1a2e")
        VStack(spacing: 24) {
            BreadyIconView(size: 200)
            HStack(spacing: 16) {
                BreadyIconView(size: 76)
                BreadyIconView(size: 60)
                BreadyIconView(size: 40)
            }
        }
    }
    .ignoresSafeArea()
}
