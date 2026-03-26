import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var store: ProductStore
    @State private var showAddItem    = false
    @State private var showClearAlert = false
    @State private var searchText     = ""

    var unpurchased: [ShoppingItem] {
        store.shoppingItems
            .filter { !$0.isPurchased }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.brand.localizedCaseInsensitiveContains(searchText) }
    }
    var purchased: [ShoppingItem] {
        store.shoppingItems
            .filter { $0.isPurchased }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.brand.localizedCaseInsensitiveContains(searchText) }
    }

    var shareText: String {
        let lines = store.shoppingItems
            .filter { !$0.isPurchased }
            .map { item -> String in
                var line = "• \(item.name)"
                if !item.brand.isEmpty { line += " (\(item.brand))" }
                if item.quantity > 1   { line += " ×\(item.quantity)" }
                return line
            }
        return lines.isEmpty ? "Shopping list is empty." : lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.shoppingItems.isEmpty {
                    ContentUnavailableView(
                        "Shopping List Empty",
                        systemImage: "cart",
                        description: Text("Items you need to restock will appear here.")
                    )
                } else {
                    List {
                        if !unpurchased.isEmpty {
                            Section("To Buy") {
                                ForEach(unpurchased) { item in
                                    ShoppingRow(item: item)
                                }
                                .onDelete { idx in
                                    idx.forEach { store.deleteShoppingItem(unpurchased[$0]) }
                                }
                            }
                        }

                        if !purchased.isEmpty {
                            Section {
                                ForEach(purchased) { item in
                                    ShoppingRow(item: item)
                                }
                                .onDelete { idx in
                                    idx.forEach { store.deleteShoppingItem(purchased[$0]) }
                                }
                            } header: {
                                HStack {
                                    Text("Purchased")
                                    Spacer()
                                    Button("Clear", role: .destructive) {
                                        showClearAlert = true
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Search list…")
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(store.shoppingItems.filter { !$0.isPurchased }.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddItem = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddShoppingItemSheet(isPresented: $showAddItem)
            }
            .alert("Clear Purchased Items?", isPresented: $showClearAlert) {
                Button("Clear All", role: .destructive) { store.clearPurchasedItems() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all purchased items from your list.")
            }
        }
    }
}

// MARK: - Shopping Row
struct ShoppingRow: View {
    @EnvironmentObject var store: ProductStore
    let item: ShoppingItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.toggleShoppingItem(item)
                HapticFeedback.impact(.light)
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? .teal : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .strikethrough(item.isPurchased, color: .secondary)
                    .foregroundStyle(item.isPurchased ? .secondary : .primary)
                if !item.brand.isEmpty {
                    Text(item.brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.quantity > 1 {
                Text("×\(item.quantity)")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Shopping Item Sheet
struct AddShoppingItemSheet: View {
    @EnvironmentObject var store: ProductStore
    @Binding var isPresented: Bool
    @State private var name     = ""
    @State private var brand    = ""
    @State private var quantity = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name *", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }
                Section("Quantity") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }
            }
            .navigationTitle("Add to Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let item = ShoppingItem(
                            name:     name.trimmingCharacters(in: .whitespaces),
                            brand:    brand.trimmingCharacters(in: .whitespaces),
                            quantity: quantity
                        )
                        store.addShoppingItem(item)
                        HapticFeedback.notification(.success)
                        isPresented = false
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
