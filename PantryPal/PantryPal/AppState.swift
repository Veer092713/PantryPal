import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var filterStatus: ExpiryStatus? = nil
    @Published var selectedTab: Int = 0
    @Published var onboardingCompleted: Bool

    init() {
        self.onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
    }

    func completeOnboarding() {
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
    }
}
