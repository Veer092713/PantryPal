import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store:    ProductStore
    @EnvironmentObject var appState: AppState
    @State private var bannerProduct: Product? = nil
    @State private var showBanner     = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem { Label("Home",       systemImage: "house.fill") }
                    .tag(0)

                ProductListView()
                    .tabItem { Label("All Items",  systemImage: "list.bullet") }
                    .tag(1)

                ShoppingListView()
                    .tabItem { Label("Shopping",   systemImage: "cart.fill") }
                    .tag(2)

                CategoriesView()
                    .tabItem { Label("Categories", systemImage: "square.grid.2x2.fill") }
                    .tag(3)

                SettingsView()
                    .tabItem { Label("Settings",   systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .tint(.teal)

            if showBanner, let product = bannerProduct {
                ExpiryBanner(product: product) {
                    withAnimation { showBanner = false }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .onAppear { checkForExpiringItems() }
        .onChange(of: store.products) { _, _ in checkForExpiringItems() }
        .onChange(of: store.shoppingItems) { _, newItems in
            NotificationManager.shared.scheduleShoppingListReminder(items: newItems, settings: store.settings)
        }
        // Surface Firestore errors to the user
        .alert("Sync Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }

    private func checkForExpiringItems() {
        let threshold = store.settings.notifyDaysBefore
        if let soonest = store.expiringProducts(withinDays: threshold).first {
            bannerProduct = soonest
            withAnimation(.spring()) { showBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation { showBanner = false }
            }
        }
    }
}
