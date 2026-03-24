import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ProductStore
    @State private var notificationManager = NotificationManager()
    @State private var selectedTab    = 0
    @State private var showAddProduct = false
    @State private var bannerProduct: Product? = nil
    @State private var showBanner     = false
    @State private var filterStatus: ExpiryStatus? = nil

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                HomeView(showAddProduct: $showAddProduct, selectedTab: $selectedTab, filterStatus: $filterStatus)
                    .tabItem { Label("Home",       systemImage: "house.fill") }
                    .tag(0)

                ProductListView(filterStatus: $filterStatus)
                    .tabItem { Label("All Items",  systemImage: "list.bullet") }
                    .tag(1)

                CategoriesView()
                    .tabItem { Label("Categories", systemImage: "square.grid.2x2.fill") }
                    .tag(2)

                SettingsView()
                    .tabItem { Label("Settings",   systemImage: "gearshape.fill") }
                    .tag(3)
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
        .sheet(isPresented: $showAddProduct) {
            AddProductView(isPresented: $showAddProduct)
        }
        .onAppear { checkForExpiringItems() }
        .onChange(of: store.products) { _, _ in checkForExpiringItems() }
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
