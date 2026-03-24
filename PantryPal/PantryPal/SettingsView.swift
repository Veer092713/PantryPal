import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: ProductStore
    @EnvironmentObject var auth:  AuthManager
    @State private var notificationManager = NotificationManager()
    @State private var showResetAlert  = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Notifications", isOn: $store.settings.notificationsEnabled)
                        .tint(.teal)

                    if store.settings.notificationsEnabled {
                        Picker("Check Interval", selection: $store.settings.notificationInterval) {
                            ForEach(NotificationInterval.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }

                        Stepper(
                            "Alert \(store.settings.notifyDaysBefore) day(s) before",
                            value: $store.settings.notifyDaysBefore,
                            in: 1...14
                        )
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("You'll be notified when items are approaching their expiry date.")
                }

                Section("Statistics") {
                    LabeledContent("Total Products", value: "\(store.products.count)")
                    LabeledContent("Expired",        value: "\(store.products.filter { $0.status == .expired  }.count)")
                    LabeledContent("Expiring Soon",  value: "\(store.products.filter { $0.status == .critical }.count)")
                    LabeledContent("Categories",     value: "\(store.categories.count)")
                }

                Section("Account") {
                    if !auth.userEmail.isEmpty {
                        LabeledContent("Signed in as", value: auth.userEmail)
                    }
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("About") {
                    LabeledContent("App",     value: "PantryPal")
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Storage", value: "Firebase Firestore")
                }


                Section("App Icon") {
                    NavigationLink(destination: IconExporterView()) {
                        Label("Export App Icon", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Delete All Products", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: store.settings) { _, _ in
                store.saveSettings()
                notificationManager.scheduleAll(products: store.products, settings: store.settings)
            }
            .alert("Sign Out?", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be signed out. Your data is saved in the cloud and will be available when you sign back in.")
            }
            .alert("Delete All Products?", isPresented: $showResetAlert) {
                Button("Delete All", role: .destructive) {
                    store.products.forEach { store.deleteProduct($0) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all tracked products. This cannot be undone.")
            }
        }
    }
}
