import Foundation
import Combine
@preconcurrency import FirebaseFirestore
import SwiftUI
import WidgetKit

@MainActor
final class ProductStore: ObservableObject {
    @Published var products:      [Product]      = []
    @Published var categories:    [Category]     = []
    @Published var shoppingItems: [ShoppingItem] = []
    @Published var wasteLog:      [WasteEntry]   = []
    @Published var settings:      AppSettings    = AppSettings()
    @Published var lastError:     String?        = nil

    private let db = Firestore.firestore()
    private var userID: String?
    private var productsListener:      ListenerRegistration?
    private var categoriesListener:    ListenerRegistration?
    private var shoppingItemsListener: ListenerRegistration?
    private var wasteLogListener:      ListenerRegistration?

    // MARK: - Lifecycle

    func configure(userID: String) {
        self.userID = userID
        loadSettings()
        attachListeners()
    }

    func clear() {
        productsListener?.remove()
        categoriesListener?.remove()
        shoppingItemsListener?.remove()
        wasteLogListener?.remove()
        productsListener      = nil
        categoriesListener    = nil
        shoppingItemsListener = nil
        wasteLogListener      = nil
        products      = []
        categories    = []
        shoppingItems = []
        wasteLog      = []
        userID        = nil
    }

    // MARK: - Firestore Collection References

    private func productsRef() -> CollectionReference? {
        guard let uid = userID else { return nil }
        return db.collection("users").document(uid).collection("products")
    }

    private func categoriesRef() -> CollectionReference? {
        guard let uid = userID else { return nil }
        return db.collection("users").document(uid).collection("categories")
    }

    private func shoppingItemsRef() -> CollectionReference? {
        guard let uid = userID else { return nil }
        return db.collection("users").document(uid).collection("shoppingItems")
    }

    private func wasteLogRef() -> CollectionReference? {
        guard let uid = userID else { return nil }
        return db.collection("users").document(uid).collection("wasteLog")
    }

    private func settingsDocRef() -> DocumentReference? {
        guard let uid = userID else { return nil }
        return db.collection("users").document(uid).collection("settings").document("app")
    }

    // MARK: - Real-time Listeners

    private func attachListeners() {
        guard let pRef = productsRef(),
              let cRef = categoriesRef(),
              let sRef = shoppingItemsRef(),
              let wRef = wasteLogRef() else { return }

        productsListener = pRef.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("🔴 Firestore products error: \(error.localizedDescription)")
                Task { @MainActor [weak self] in self?.lastError = "Products sync error: \(error.localizedDescription)" }
                return
            }
            let loaded = snapshot?.documents.compactMap { Product(from: $0.data()) } ?? []
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.products = loaded.sorted { $0.expiryDate < $1.expiryDate }
                self.writeWidgetData()
            }
        }

        categoriesListener = cRef.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("🔴 Firestore categories error: \(error.localizedDescription)")
                Task { @MainActor [weak self] in self?.lastError = "Categories sync error: \(error.localizedDescription)" }
                return
            }
            let loaded    = snapshot?.documents.compactMap { Category(from: $0.data()) } ?? []
            let fromCache = snapshot?.metadata.isFromCache ?? true
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.categories = loaded
                if self.categories.isEmpty && !fromCache {
                    self.seedDefaults()
                }
            }
        }

        shoppingItemsListener = sRef.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("🔴 Firestore shoppingItems error: \(error.localizedDescription)")
                Task { @MainActor [weak self] in self?.lastError = "Shopping list sync error: \(error.localizedDescription)" }
                return
            }
            let loaded = snapshot?.documents.compactMap { ShoppingItem(from: $0.data()) } ?? []
            Task { @MainActor [weak self] in
                self?.shoppingItems = loaded.sorted { $0.addedDate > $1.addedDate }
            }
        }

        wasteLogListener = wRef.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("🔴 Firestore wasteLog error: \(error.localizedDescription)")
                return
            }
            let loaded = snapshot?.documents.compactMap { WasteEntry(from: $0.data()) } ?? []
            Task { @MainActor [weak self] in
                self?.wasteLog = loaded.sorted { $0.date > $1.date }
            }
        }
    }

    // MARK: - Products CRUD

    func addProduct(_ p: Product) {
        productsRef()?.document(p.id.uuidString).setData(p.firestoreData) { [weak self] error in
            if let error {
                print("🔴 addProduct failed: \(error.localizedDescription)")
                Task { @MainActor [weak self] in self?.lastError = "Failed to add product." }
            }
        }
    }

    func updateProduct(_ p: Product) {
        productsRef()?.document(p.id.uuidString).setData(p.firestoreData) { [weak self] error in
            if let error {
                print("🔴 updateProduct failed: \(error.localizedDescription)")
                Task { @MainActor [weak self] in self?.lastError = "Failed to update product." }
            }
        }
    }

    func deleteProduct(_ p: Product) {
        NotificationManager.shared.cancelNotification(for: p)
        productsRef()?.document(p.id.uuidString).delete { [weak self] error in
            if let error {
                print("🔴 deleteProduct failed: \(error.localizedDescription)")
                Task { @MainActor [weak self] in self?.lastError = "Failed to delete product." }
            }
        }
    }

    func deleteExpiredProducts() {
        products.filter { $0.status == .expired }.forEach { p in
            addWasteEntry(WasteEntry(productName: p.name, productBrand: p.brand, wasWasted: true))
            deleteProduct(p)
        }
    }

    /// Decrements quantity by 1. Deletes the product when it reaches 0.
    func decrementQuantity(for product: Product) {
        if product.quantity > 1 {
            var updated = product
            updated.quantity -= 1
            updateProduct(updated)
            NotificationManager.shared.scheduleExpiryNotification(for: updated, settings: settings)
        } else {
            deleteProduct(product)
        }
    }

    /// Records a waste entry and deletes the product.
    func consumeProduct(_ product: Product, wasWasted: Bool) {
        addWasteEntry(WasteEntry(productName: product.name, productBrand: product.brand, wasWasted: wasWasted))
        deleteProduct(product)
    }

    // MARK: - Categories CRUD

    func addCategory(_ c: Category) {
        categoriesRef()?.document(c.id.uuidString).setData(c.firestoreData) { error in
            if let error { print("🔴 addCategory failed: \(error.localizedDescription)") }
        }
    }

    func deleteCategory(_ c: Category) {
        categoriesRef()?.document(c.id.uuidString).delete { error in
            if let error { print("🔴 deleteCategory failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Shopping Items CRUD

    func addShoppingItem(_ item: ShoppingItem) {
        shoppingItemsRef()?.document(item.id.uuidString).setData(item.firestoreData) { error in
            if let error { print("🔴 addShoppingItem failed: \(error.localizedDescription)") }
        }
    }

    func deleteShoppingItem(_ item: ShoppingItem) {
        shoppingItemsRef()?.document(item.id.uuidString).delete { error in
            if let error { print("🔴 deleteShoppingItem failed: \(error.localizedDescription)") }
        }
    }

    func toggleShoppingItem(_ item: ShoppingItem) {
        var updated = item
        updated.isPurchased.toggle()
        shoppingItemsRef()?.document(item.id.uuidString).setData(updated.firestoreData) { error in
            if let error { print("🔴 toggleShoppingItem failed: \(error.localizedDescription)") }
        }
    }

    func clearPurchasedItems() {
        shoppingItems.filter { $0.isPurchased }.forEach { deleteShoppingItem($0) }
    }

    // MARK: - Waste Log

    func addWasteEntry(_ entry: WasteEntry) {
        wasteLogRef()?.document(entry.id.uuidString).setData(entry.firestoreData) { error in
            if let error { print("🔴 addWasteEntry failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Waste Stats (current month)

    var consumedThisMonth: Int {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        return wasteLog.filter { !$0.wasWasted && $0.date >= start }.count
    }

    var wastedThisMonth: Int {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        return wasteLog.filter { $0.wasWasted && $0.date >= start }.count
    }

    // MARK: - Settings (per-user UserDefaults + Firestore sync)

    func saveSettings() {
        let key = settingsKey
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
        // Sync to Firestore so settings follow the user across devices
        let remote: [String: Any] = [
            "notificationsEnabled":              settings.notificationsEnabled,
            "notifyDaysBefore":                  settings.notifyDaysBefore,
            "notificationInterval":              settings.notificationInterval.rawValue,
            "shoppingListNotificationsEnabled":  settings.shoppingListNotificationsEnabled,
            "shoppingListNotificationInterval":  settings.shoppingListNotificationInterval.rawValue
        ]
        settingsDocRef()?.setData(remote) { error in
            if let error { print("🔴 saveSettings failed: \(error.localizedDescription)") }
        }
    }

    private var settingsKey: String {
        userID.map { "dk_settings_\($0)" } ?? "dk_settings"
    }

    private func loadSettings() {
        // 1. Load from local cache first (instant)
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let s    = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = s
        }
        // 2. Pull latest from Firestore in the background
        settingsDocRef()?.getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                var s = AppSettings()
                s.notificationsEnabled             = data["notificationsEnabled"]             as? Bool ?? true
                s.notifyDaysBefore                 = data["notifyDaysBefore"]                 as? Int  ?? 3
                s.shoppingListNotificationsEnabled = data["shoppingListNotificationsEnabled"] as? Bool ?? false
                if let raw = data["notificationInterval"] as? String {
                    s.notificationInterval = NotificationInterval(rawValue: raw) ?? .daily
                }
                if let raw = data["shoppingListNotificationInterval"] as? String {
                    s.shoppingListNotificationInterval = NotificationInterval(rawValue: raw) ?? .weekly
                }
                self.settings = s
                // Update local cache with the freshly-loaded value
                if let encoded = try? JSONEncoder().encode(s) {
                    UserDefaults.standard.set(encoded, forKey: self.settingsKey)
                }
            }
        }
    }

    // MARK: - Query Helpers

    func products(for category: Category) -> [Product] {
        products.filter { $0.categoryID == category.id }
    }

    func category(for product: Product) -> Category? {
        categories.first { $0.id == product.categoryID }
    }

    func expiringProducts(withinDays days: Int) -> [Product] {
        products.filter { $0.daysUntilExpiry >= 0 && $0.daysUntilExpiry <= days }
    }

    // MARK: - Widget Data

    private func writeWidgetData() {
        // App Group data sharing requires a paid Apple Developer account.
        // Once you have one, register "group.com.pantrypal.shared" in the portal,
        // add the entitlement back to both targets, and uncomment the block below.
        WidgetCenter.shared.reloadAllTimelines()

        // let appGroupID = "group.com.pantrypal.shared"
        // guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        // let items = expiringProducts(withinDays: 7).prefix(5).map { p -> [String: Any] in
        //     ["name": p.name, "daysLeft": p.daysUntilExpiry, "status": p.status.rawValue]
        // }
        // if let data = try? JSONSerialization.data(withJSONObject: Array(items)) {
        //     defaults.set(data, forKey: "pantrypal.expiring")
        // }
    }

    // MARK: - Private

    private func seedDefaults() {
        Category.defaults.forEach { addCategory($0) }
    }
}
