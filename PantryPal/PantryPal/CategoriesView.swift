import SwiftUI

// MARK: - CategoriesView
struct CategoriesView: View {
    @EnvironmentObject var store: ProductStore
    @State private var showAddCategory = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.categories) { category in
                    NavigationLink(destination: CategoryProductsView(category: category)) {
                        CategoryRow(category: category)
                    }
                }
                .onDelete { idx in
                    // Prevent deletion of default categories
                    idx.forEach { i in
                        let cat = store.categories[i]
                        if !Category.defaults.contains(where: { $0.name == cat.name }) {
                            store.deleteCategory(cat)
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(isPresented: $showAddCategory)
            }
        }
    }
}

// MARK: - CategoryRow
struct CategoryRow: View {
    @EnvironmentObject var store: ProductStore
    let category: Category

    var count: Int { store.products(for: category).count }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(category.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(category.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name).font(.subheadline.bold())
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CategoryProductsView
struct CategoryProductsView: View {
    @EnvironmentObject var store: ProductStore
    let category: Category

    var products: [Product] { store.products(for: category) }

    var body: some View {
        Group {
            if products.isEmpty {
                ContentUnavailableView("No Items", systemImage: category.icon,
                    description: Text("No items in \(category.name) yet."))
            } else {
                List(products) { product in
                    NavigationLink(destination: ProductDetailView(product: product)) {
                        ProductRow(product: product, category: category)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - AddCategoryView
struct AddCategoryView: View {
    @EnvironmentObject var store: ProductStore
    @Binding var isPresented: Bool

    @State private var name:         String = ""
    @State private var selectedIcon  = "tag"
    @State private var selectedColor = "#2A9D8F"

    let icons = [
        "tag", "cart", "bag", "fork.knife", "cup.and.saucer",
        "refrigerator", "cabinet", "snowflake", "flame", "leaf",
        "wineglass", "birthday.cake", "fish", "carrot", "pills"
    ]
    let colors = [
        "#2A9D8F", "#E76F51", "#F4A261", "#E9C46A", "#264653",
        "#457B9D", "#A8DADC", "#6D6875", "#B5838D", "#E63946"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        selectedIcon == icon
                                        ? Color(hex: selectedColor).opacity(0.2)
                                        : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .foregroundStyle(
                                        selectedIcon == icon
                                        ? Color(hex: selectedColor)
                                        : .secondary
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().strokeBorder(.white, lineWidth: selectedColor == hex ? 3 : 0)
                                    )
                                    .shadow(color: Color(hex: hex).opacity(0.5),
                                            radius: selectedColor == hex ? 6 : 0)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Preview
                Section("Preview") {
                    CategoryRow(category: Category(name: name.isEmpty ? "Category" : name,
                                                   icon: selectedIcon,
                                                   colorHex: selectedColor))
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let cat = Category(name: name.trimmingCharacters(in: .whitespaces),
                                           icon: selectedIcon,
                                           colorHex: selectedColor)
                        store.addCategory(cat)
                        isPresented = false
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
