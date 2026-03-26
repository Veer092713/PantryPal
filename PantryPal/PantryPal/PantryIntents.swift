import AppIntents
import Foundation

// MARK: - 1. Add Product

struct AddProductIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Pantry Product"
    static var description = IntentDescription(
        "Add a product to your pantry with an expiry date.",
        categoryName: "Pantry"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Product Name", description: "The name of the product to add.")
    var productName: String

    @Parameter(title: "Expiry Date", description: "The date the product expires.")
    var expiryDate: Date

    func perform() async throws -> some ProvidesDialog {
        let store = PantryIntentStore.shared
        let category = try await store.defaultCategory()
        let product = Product(
            name: productName,
            brand: "",
            categoryID: category.id,
            expiryDate: expiryDate
        )
        try await store.addProduct(product)
        let formatted = expiryDate.formatted(date: .long, time: .omitted)
        return .result(dialog: "\(productName) has been added to your pantry. It expires on \(formatted).")
    }
}

// MARK: - 2. Add to Shopping List

struct AddShoppingItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Shopping List"
    static var description = IntentDescription(
        "Add an item to your PantryPilot shopping list.",
        categoryName: "Shopping"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Item Name", description: "The name of the item to add.")
    var itemName: String

    func perform() async throws -> some ProvidesDialog {
        let store = PantryIntentStore.shared
        let item = ShoppingItem(name: itemName)
        try await store.addShoppingItem(item)
        return .result(dialog: "\(itemName) has been added to your shopping list.")
    }
}

// MARK: - 3. Check Shopping List

struct CheckShoppingListIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Shopping List"
    static var description = IntentDescription(
        "Check whether an item is on your shopping list.",
        categoryName: "Shopping"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Item Name", description: "The item to look for.")
    var itemName: String

    func perform() async throws -> some ProvidesDialog {
        let store = PantryIntentStore.shared
        if let item = try await store.findShoppingItem(named: itemName) {
            if item.isPurchased {
                return .result(dialog: "Yes, \(item.name) is on your shopping list and already marked as purchased.")
            } else {
                return .result(dialog: "Yes, \(item.name) is on your shopping list.")
            }
        } else {
            return .result(dialog: "No, \(itemName) is not on your shopping list.")
        }
    }
}

// MARK: - 4. Check Expiry Date

struct CheckExpiryIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Product Expiry"
    static var description = IntentDescription(
        "Find out when a product in your pantry expires.",
        categoryName: "Pantry"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Product Name", description: "The product to check.")
    var productName: String

    func perform() async throws -> some ProvidesDialog {
        let store = PantryIntentStore.shared
        guard let product = try await store.findProduct(named: productName) else {
            throw IntentError.productNotFound(productName)
        }
        let days = product.daysUntilExpiry
        let formatted = product.expiryDate.formatted(date: .long, time: .omitted)
        switch days {
        case ..<0:
            return .result(dialog: "\(product.name) expired \(abs(days)) days ago, on \(formatted).")
        case 0:
            return .result(dialog: "\(product.name) expires today.")
        case 1:
            return .result(dialog: "\(product.name) expires tomorrow, on \(formatted).")
        default:
            return .result(dialog: "\(product.name) expires on \(formatted), in \(days) days.")
        }
    }
}
