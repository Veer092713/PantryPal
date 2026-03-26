import SwiftUI

// MARK: - ProductListView
struct ProductListView: View {
    @EnvironmentObject var store:    ProductStore
    @EnvironmentObject var appState: AppState
    @State private var searchText   = ""
    @State private var sortOption   = SortOption.expiryDate
    @State private var showAddSheet = false
    @State private var showDeleteExpiredAlert = false

    enum SortOption: String, CaseIterable {
        case expiryDate = "Expiry Date"
        case name       = "Name"
        case added      = "Date Added"
    }

    var expiredCount: Int { store.products.filter { $0.status == .expired }.count }

    var filtered: [Product] {
        var list = store.products
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let status = appState.filterStatus {
            list = list.filter { $0.status == status }
        }
        switch sortOption {
        case .expiryDate: list.sort { $0.expiryDate < $1.expiryDate }
        case .name:       list.sort { $0.name       < $1.name       }
        case .added:      list.sort { $0.addedDate  > $1.addedDate  }
        }
        return list
    }

    var navTitle: String { appState.filterStatus?.rawValue ?? "All Items" }

    var body: some View {
        NavigationStack {
            Group {
                if store.products.isEmpty {
                    ContentUnavailableView("No Products", systemImage: "cart", description: Text("Add items by scanning."))
                } else {
                    List {
                        ForEach(filtered) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                ProductRow(product: product, category: store.category(for: product))
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    let item = ShoppingItem(name: product.name, brand: product.brand)
                                    store.addShoppingItem(item)
                                    HapticFeedback.notification(.success)
                                } label: {
                                    Label("Add to List", systemImage: "cart.badge.plus")
                                }
                                .tint(.teal)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.deleteProduct(product)
                                    HapticFeedback.notification(.warning)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Search products…")
            .navigationTitle(navTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        if expiredCount > 0 {
                            Divider()
                            Button(role: .destructive) {
                                showDeleteExpiredAlert = true
                            } label: {
                                Label("Delete All Expired (\(expiredCount))", systemImage: "trash")
                            }
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                }
                if appState.filterStatus != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { appState.filterStatus = nil } label: {
                            Label("Clear Filter", systemImage: "xmark.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddProductView(isPresented: $showAddSheet)
            }
            .alert("Delete All Expired?", isPresented: $showDeleteExpiredAlert) {
                Button("Delete \(expiredCount) Items", role: .destructive) {
                    store.deleteExpiredProducts()
                    HapticFeedback.notification(.warning)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all \(expiredCount) expired products.")
            }
        }
    }
}

// MARK: - ProductRow
struct ProductRow: View {
    let product: Product
    let category: Category?

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(product.status.color)
                .frame(width: 4, height: 44)

            // Product image or icon
            Group {
                if let data = product.imageData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable().scaledToFill()
                } else {
                    Image(systemName: category?.icon ?? "bag")
                        .foregroundStyle(category?.color ?? .accentColor)
                        .font(.title3)
                }
            }
            .frame(width: 44, height: 44)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name).font(.subheadline.bold()).lineLimit(1)
                if !product.brand.isEmpty {
                    Text(product.brand).font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if product.quantity > 1 {
                    Text("×\(product.quantity)")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                }
                HStack(spacing: 4) {
                    Image(systemName: product.status.icon)
                    Text(expiryLabel)
                }
                .font(.caption.bold())
                .foregroundStyle(product.status.color)

                Text(product.expiryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    var expiryLabel: String {
        switch product.daysUntilExpiry {
        case ..<0:  return "Expired"
        case 0:     return "Today"
        case 1:     return "Tomorrow"
        default:    return "\(product.daysUntilExpiry)d"
        }
    }
}

// MARK: - ProductDetailView
struct ProductDetailView: View {
    @EnvironmentObject var store: ProductStore
    @Environment(\.dismiss) var dismiss
    @State private var showEdit              = false
    @State private var showConsumeOptions    = false
    @State private var showDeleteConfirm     = false
    @State private var showAddToShoppingList = false
    @State private var pendingWasted: Bool   = false   // tracks consume reason until alert resolved
    @State var product: Product

    var category: Category? { store.category(for: product) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Image
                Group {
                    if let data = product.imageData, let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Rectangle().fill((category?.color ?? .teal).opacity(0.15))
                            Image(systemName: category?.icon ?? "bag")
                                .font(.system(size: 60))
                                .foregroundStyle(category?.color ?? .teal)
                        }
                    }
                }
                .frame(height: 200)
                .clipped()

                VStack(spacing: 16) {
                    // Title + badge
                    HStack {
                        VStack(alignment: .leading) {
                            Text(product.name).font(.title2.bold())
                            if !product.brand.isEmpty {
                                Text(product.brand).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Label(product.status.rawValue, systemImage: product.status.icon)
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(product.status.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(product.status.color)
                    }

                    Divider()

                    detailRow("Quantity",   value: "\(product.quantity)",                                           icon: "number")
                    detailRow("Category",   value: category?.name ?? "—",                                          icon: category?.icon ?? "tag")
                    detailRow("Expires",    value: product.expiryDate.formatted(date: .long, time: .omitted),      icon: "calendar")
                    detailRow("Added",      value: product.addedDate.formatted(date: .abbreviated, time: .omitted), icon: "plus.circle")
                    if let barcode = product.barcode {
                        detailRow("Barcode", value: barcode, icon: "barcode")
                    }
                    if !product.notes.isEmpty {
                        detailRow("Notes", value: product.notes, icon: "note.text")
                    }
                }
                .padding()
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { showEdit = true }

                    Divider()

                    // Use One — decrements quantity (or deletes if qty == 1)
                    if product.quantity > 1 {
                        Button {
                            store.decrementQuantity(for: product)
                            HapticFeedback.impact(.light)
                            // Refresh local state from store
                            if let updated = store.products.first(where: { $0.id == product.id }) {
                                product = updated
                            } else {
                                dismiss()
                            }
                        } label: {
                            Label("Use One (\(product.quantity - 1) remaining)", systemImage: "minus.circle")
                        }
                    }

                    Button("Used It Up / Discard") { showConsumeOptions = true }

                    Divider()

                    Button("Delete", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddProductView(isPresented: $showEdit, editingProduct: product)
        }
        // Step 1: ask HOW the product is being removed
        .confirmationDialog("How are you removing \(product.name)?",
                            isPresented: $showConsumeOptions,
                            titleVisibility: .visible) {
            Button("Used It Up") {
                pendingWasted = false
                showAddToShoppingList = true
            }
            Button("Discarded / Threw Away") {
                pendingWasted = true
                showAddToShoppingList = true
            }
            Button("Cancel", role: .cancel) {}
        }
        // Step 2: offer shopping list — THEN delete + dismiss
        .alert("Add to Shopping List?", isPresented: $showAddToShoppingList) {
            Button("Add to List") {
                let item = ShoppingItem(name: product.name, brand: product.brand)
                store.addShoppingItem(item)
                store.consumeProduct(product, wasWasted: pendingWasted)
                HapticFeedback.notification(.success)
                dismiss()
            }
            Button("No Thanks", role: .cancel) {
                store.consumeProduct(product, wasWasted: pendingWasted)
                dismiss()
            }
        } message: {
            Text("Would you like to add \(product.name) to your shopping list so you remember to restock?")
        }
        // Plain delete without shopping list prompt
        .confirmationDialog("Delete \(product.name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deleteProduct(product)
                HapticFeedback.notification(.warning)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove it from your pantry.")
        }
        .onAppear {
            if let updated = store.products.first(where: { $0.id == product.id }) {
                product = updated
            }
        }
        .onChange(of: store.products) { _, _ in
            if let updated = store.products.first(where: { $0.id == product.id }) {
                product = updated
            }
        }
    }

    @ViewBuilder
    func detailRow(_ label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.teal)
            VStack(alignment: .leading) {
                Text(label).font(.caption).foregroundColor(.secondary)
                Text(value).font(.subheadline)
            }
            Spacer()
        }
    }
}
