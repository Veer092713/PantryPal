import SwiftUI

// MARK: - ProductListView
struct ProductListView: View {
    @EnvironmentObject var store: ProductStore
    @State private var searchText   = ""
    @State private var sortOption   = SortOption.expiryDate
    @Binding var filterStatus: ExpiryStatus?
    @State private var showAddSheet = false

    enum SortOption: String, CaseIterable {
        case expiryDate = "Expiry Date"
        case name       = "Name"
        case added      = "Date Added"
    }

    var filtered: [Product] {
        var list = store.products
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let status = filterStatus {
            list = list.filter { $0.status == status }
        }
        switch sortOption {
        case .expiryDate: list.sort { $0.expiryDate < $1.expiryDate }
        case .name:       list.sort { $0.name       < $1.name       }
        case .added:      list.sort { $0.addedDate  > $1.addedDate  }
        }
        return list
    }

    var navTitle: String { filterStatus?.rawValue ?? "All Items" }

    var body: some View {
        NavigationStack {
            Group {
                if store.products.isEmpty {
                    ContentUnavailableView("No Products", systemImage: "cart", description: Text("Add items by scanning."))
                } else {
                    List {
                        ForEach(filtered) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                ProductRow(product: product)
                            }
                        }
                        .onDelete { idx in
                            idx.forEach { store.deleteProduct(filtered[$0]) }
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
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                }
                if filterStatus != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { filterStatus = nil } label: {
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
        }
    }
}

// MARK: - ProductRow
struct ProductRow: View {
    @EnvironmentObject var store: ProductStore
    let product: Product

    var category: Category? { store.category(for: product) }

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
    @State private var showEdit = false
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

                    detailRow("Category",   value: category?.name ?? "—",     icon: category?.icon ?? "tag")
                    detailRow("Expires",    value: product.expiryDate.formatted(date: .long, time: .omitted), icon: "calendar")
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
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddProductView(isPresented: $showEdit, editingProduct: product)
        }
        .onAppear {
            // Refresh in case of edit
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
