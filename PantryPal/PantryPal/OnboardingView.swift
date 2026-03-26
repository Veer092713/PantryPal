import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "shippingbox.fill",
            iconColor: .teal,
            title: "Welcome to PantryPal",
            body: "Track everything in your pantry, fridge, and freezer. Know what's fresh and what needs to be used before it's too late.",
            accentColor: .teal
        ),
        OnboardingPage(
            icon: "barcode.viewfinder",
            iconColor: .orange,
            title: "Scan & Track Instantly",
            body: "Scan a barcode to auto-fill product details, or scan the expiry date directly from the packaging. No typing required.",
            accentColor: .orange
        ),
        OnboardingPage(
            icon: "cart.fill",
            iconColor: .green,
            title: "Stay Stocked, Waste Less",
            body: "Get notified before items expire, build a shared shopping list automatically, and track how much food you save each month.",
            accentColor: .green
        )
    ]

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.00, green: 0.25, blue: 0.31),
                         Color(red: 0.00, green: 0.46, blue: 0.54)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page carousel
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // CTA
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        Button {
                            withAnimation(.spring()) {
                                appState.completeOnboarding()
                            }
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Color.teal.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .transition(.opacity)
                    } else {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("Next")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Button("Skip") {
                            appState.completeOnboarding()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
                .animation(.easeInOut(duration: 0.22), value: currentPage)
            }
        }
    }
}

// MARK: - Page Model
private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
    let accentColor: Color
}

// MARK: - Single Page View
private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(page.accentColor.opacity(0.08))
                    .frame(width: 210, height: 210)
                Image(systemName: page.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(page.accentColor)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
