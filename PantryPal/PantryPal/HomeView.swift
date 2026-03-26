import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store:    ProductStore
    @EnvironmentObject var auth:     AuthManager
    @EnvironmentObject var appState: AppState
    @State private var showAddProduct = false

    var statusCounts: (expired: Int, critical: Int, warning: Int, fresh: Int) {
        var expired = 0, critical = 0, warning = 0, fresh = 0
        for p in store.products {
            switch p.status {
            case .expired:  expired  += 1
            case .critical: critical += 1
            case .warning:  warning  += 1
            case .good:     fresh    += 1
            }
        }
        return (expired, critical, warning, fresh)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.userEmail.isEmpty ? "Hello!" : "Hello, \(auth.displayName)!")
                                .font(.subheadline)
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                            Text("PantryPal")
                                .font(.largeTitle.bold())
                            Text(Date().formatted(date: .long, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 1) {
                            Text("P")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.teal)
                            Text("antry")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.teal.opacity(0.85))
                            Text("P")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.teal)
                                .padding(.leading, 3)
                            Text("al")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.teal.opacity(0.85))
                        }
                    }
                    .padding(.horizontal)

                    // MARK: Big Scan Button
                    Button {
                        showAddProduct = true
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.teal.gradient)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .teal.opacity(0.4), radius: 16, y: 8)
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                            }
                            Text("Scan Product")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            Text("Tap to scan a barcode or expiry date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.teal.opacity(0.3), lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal)

                    // MARK: Status Summary Cards
                    if store.products.isEmpty {
                        ContentUnavailableView("No Items Yet",
                            systemImage: "cart.badge.plus",
                            description: Text("Scan your first product to get started."))
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status Overview")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                Button {
                                    appState.filterStatus = .expired
                                    appState.selectedTab  = 1
                                } label: {
                                    StatusCard(label: "Expired",      count: statusCounts.expired,  status: .expired)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    appState.filterStatus = .critical
                                    appState.selectedTab  = 1
                                } label: {
                                    StatusCard(label: "Expires Soon", count: statusCounts.critical, status: .critical)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    appState.filterStatus = .warning
                                    appState.selectedTab  = 1
                                } label: {
                                    StatusCard(label: "Expiring",     count: statusCounts.warning,  status: .warning)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    appState.filterStatus = .good
                                    appState.selectedTab  = 1
                                } label: {
                                    StatusCard(label: "Fresh",        count: statusCounts.fresh,    status: .good)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)

                            HStack {
                                Spacer()
                                Text("\(store.products.count) \(store.products.count == 1 ? "item" : "items") total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.top, 2)
                        }

                        // MARK: Expiring Soon List
                        let expiring = store.expiringProducts(withinDays: store.settings.notifyDaysBefore)
                        if !expiring.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Use These First")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(expiring) { product in
                                    NavigationLink(destination: ProductDetailView(product: product)) {
                                        ProductRow(product: product, category: store.category(for: product))
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAddProduct) {
            AddProductView(isPresented: $showAddProduct)
        }
    }
}

// MARK: - StatusCard
struct StatusCard: View {
    let label: String
    let count: Int
    let status: ExpiryStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: status.icon)
                    .foregroundStyle(status.color)
                Spacer()
            }
            Text("\(count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(status.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(status.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - ExpiryBanner
struct ExpiryBanner: View {
    let product: Product
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: product.status.icon)
                .foregroundStyle(product.status.color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline.bold())
                Text(product.daysUntilExpiry == 0
                     ? "Expires today!"
                     : "Expires in \(product.daysUntilExpiry) day(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
