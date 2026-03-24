import SwiftUI

// MARK: - App Icon View
// To export: open Xcode canvas preview (Cmd+Option+Enter), right-click the preview → Save Preview

struct AppIconView: View {
    private let S: CGFloat = 500

    private var month: String {
        Date().formatted(.dateTime.month(.abbreviated)).uppercased()
    }
    private var day: String {
        Date().formatted(.dateTime.day())
    }

    var body: some View {
        ZStack {
            background
            jar
        }
        .frame(width: S, height: S)
        .clipShape(RoundedRectangle(cornerRadius: S * 0.225, style: .continuous))
    }

    // MARK: - Background
    var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.28, blue: 0.90),
                Color(red: 0.00, green: 0.60, blue: 0.68)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    // MARK: - Jar
    var jar: some View {
        ZStack {
            // Jar body — liquid glass look
            RoundedRectangle(cornerRadius: S * 0.09, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: S * 0.09, style: .continuous)
                        .strokeBorder(.white.opacity(0.65), lineWidth: 2.5)
                )

            // Left specular highlight (makes it look glassy/reflective)
            HStack {
                RoundedRectangle(cornerRadius: S * 0.05, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.32), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: S * 0.09, height: S * 0.50)
                    .padding(.leading, S * 0.025)
                Spacer()
            }

            // Top rim
            VStack {
                RoundedRectangle(cornerRadius: S * 0.025, style: .continuous)
                    .fill(.white.opacity(0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: S * 0.025, style: .continuous)
                            .strokeBorder(.white.opacity(0.60), lineWidth: 2)
                    )
                    .frame(width: S * 0.46, height: S * 0.055)
                Spacer()
            }

            // Jar contents
            jarContents
        }
        .frame(width: S * 0.60, height: S * 0.68)
        .offset(y: S * 0.04)
    }

    // MARK: - Jar Contents
    var jarContents: some View {
        ZStack {
            // Small carrot
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.58, blue: 0.05),
                                 Color(red: 0.95, green: 0.32, blue: 0.00)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: S * 0.034, height: S * 0.088)
                .rotationEffect(.degrees(-18))
                .offset(x: S * 0.105, y: S * 0.17)

            // Small leaf
            Ellipse()
                .fill(Color(red: 0.18, green: 0.72, blue: 0.22).opacity(0.88))
                .frame(width: S * 0.028, height: S * 0.062)
                .rotationEffect(.degrees(28))
                .offset(x: -S * 0.112, y: S * 0.185)

            // Expiry indicator
            expiryIndicator
        }
        .offset(y: S * 0.025)
    }

    // MARK: - Expiry Indicator
    var expiryIndicator: some View {
        let arcSize = S * 0.44
        let lw      = S * 0.037

        return ZStack {
            // 70% arc — open at bottom-left
            // Starts at 189° (just past bottom-left), sweeps clockwise 252° to 81°
            Circle()
                .trim(from: 0, to: 0.70)
                .rotation(.degrees(189))
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: Color(red: 0.10, green: 0.88, blue: 0.12), location: 0.00),
                            .init(color: .yellow,                                   location: 0.45),
                            .init(color: Color(red: 1.0, green: 0.50, blue: 0.0),   location: 0.72),
                            .init(color: .red,                                       location: 1.00)
                        ],
                        center: .center,
                        startAngle: .degrees(189),
                        endAngle:   .degrees(441)   // 189 + 252
                    ),
                    style: StrokeStyle(lineWidth: lw, lineCap: .round)
                )
                .frame(width: arcSize, height: arcSize)
                // Soft glow
                .shadow(color: .green.opacity(0.45), radius: 6)

            // Content inside the arc
            VStack(spacing: S * 0.010) {

                // Date — "NOV 12" (updates to today's date)
                HStack(spacing: S * 0.010) {
                    Text(month)
                        .font(.system(size: S * 0.075, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(day)
                        .font(.system(size: S * 0.075, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                // Gradient line + green checkmark (perpendicular to the green end)
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: S * 0.046, weight: .black))
                        .foregroundStyle(Color(red: 0.10, green: 0.88, blue: 0.12))
                        .shadow(color: .green.opacity(0.5), radius: 3)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.10, green: 0.88, blue: 0.12),
                                    .yellow,
                                    .red
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: S * 0.155, height: 2.8)
                        .clipShape(Capsule())
                }

                // FRESH label
                Text("FRESH")
                    .font(.system(size: S * 0.053, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.88, blue: 0.12))
                    .shadow(color: .green.opacity(0.4), radius: 3)
            }
        }
    }
}

// MARK: - Preview (right-click → Save Preview to export as PNG)
#Preview("App Icon 512pt") {
    AppIconView()
        .frame(width: 512, height: 512)
}
