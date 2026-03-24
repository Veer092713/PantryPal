import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: ProductStore
    @EnvironmentObject var auth:  AuthManager
    @Binding var showAddProduct: Bool
    @Binding var selectedTab: Int
    @Binding var filterStatus: ExpiryStatus?

    var expiredCount:  Int { store.products.filter { $0.status == .expired  }.count }
    var criticalCount: Int { store.products.filter { $0.status == .critical }.count }
    var warningCount:  Int { store.products.filter { $0.status == .warning  }.count }
    var laterCount:    Int { store.products.filter { $0.status == .good     }.count }

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
                                Button { filterStatus = .expired;  selectedTab = 1 } label: {
                                    StatusCard(label: "Expired",         count: expiredCount,  status: .expired)
                                }
                                .buttonStyle(.plain)
                                Button { filterStatus = .critical; selectedTab = 1 } label: {
                                    StatusCard(label: "Expires Soon",    count: criticalCount, status: .critical)
                                }
                                .buttonStyle(.plain)
                                Button { filterStatus = .warning;  selectedTab = 1 } label: {
                                    StatusCard(label: "Expiring",        count: warningCount,  status: .warning)
                                }
                                .buttonStyle(.plain)
                                Button { filterStatus = .good;     selectedTab = 1 } label: {
                                    StatusCard(label: "Expiring Later",  count: laterCount,    status: .good)
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
                                        ProductRow(product: product)
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
