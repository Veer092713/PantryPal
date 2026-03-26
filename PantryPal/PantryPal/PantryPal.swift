import SwiftUI
import UserNotifications
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct PantryPalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var auth     = AuthManager()
    @StateObject private var store    = ProductStore()
    @StateObject private var appState = AppState()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isSignedIn {
                    if appState.onboardingCompleted {
                        ContentView()
                            .environmentObject(store)
                            .environmentObject(auth)
                            .environmentObject(appState)
                    } else {
                        OnboardingView()
                            .environmentObject(appState)
                    }
                } else {
                    WelcomeView()
                        .environmentObject(auth)
                }
            }
            .onReceive(auth.$userID) { uid in
                if let uid = uid {
                    store.configure(userID: uid)
                } else {
                    store.clear()
                }
            }
        }
    }
}
