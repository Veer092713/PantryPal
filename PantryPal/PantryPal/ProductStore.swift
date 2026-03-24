import Foundation
import Combine
@preconcurrency import FirebaseFirestore
import SwiftUI

// MARK: - ProductStore (Firestore-backed, real-time)
// Each user's data lives at:
//   users/{uid}/products/{productId}
//   users/{uid}/categories/{categoryId}
// Firestore's offline persistence means the app works without internet
// and syncs automatically when connectivity is restored.

@MainActor
final class ProductStore: ObservableObject {
    @Published var products:   [Product]    = []
    @Published var categories: [Category]  = []
    @Published var settings:   AppSettings = AppSettings()

    private let db = Firestore.firestore()
    private var userID: String?
    private var productsListener:   ListenerRegistration?
    private var categoriesListener: ListenerRegistration?

    // MARK: - Lifecycle

    /// Call after sign-in with the authenticated user's UID.
    func configure(userID: String) {
        self.userID = userID
        loadSettings()
        attachListeners()
    }

    /// Call on sign-out — removes listeners and wipes local state.
    func clear() {
        productsListener?.remove()
        categoriesListener?.remove()
        productsListener   = nil
        categoriesListener = nil
        products   = []
        categories = []
        userID     = nil
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

    // MARK: - Real-time Listeners

    private func attachListeners() {
        guard let pRef = productsRef(), let cRef = categoriesRef() else { return }

        productsListener = pRef.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("🔴 Firestore products error: \(error.localizedDescription)")
                return
            }
            // Extract data before hopping to the main actor
            let loaded = snapshot?.documents.compactMap { Product(from: $0.data()) } ?? []
            Task { @MainActor [weak self] in
                self?.products = loaded.sorted { $0.expiryDate < $1.expiryDate }
            }
        }

        categoriesListener = cRef.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("🔴 Firestore categories error: \(error.localizedDescription)")
                return
            }
            let loaded      = snapshot?.documents.compactMap { Category(from: $0.data()) } ?? []
            let fromCache   = snapshot?.metadata.isFromCache ?? true
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.categories = loaded
                // Only seed default categories when Firestore confirms the server
                // has no data — never seed from a stale local cache on a new device.
                if self.categories.isEmpty && !fromCache {
                    self.seedDefaults()
                }
            }
        }
    }

    // MARK: - Products CRUD

    func addProduct(_ p: Product) {
        productsRef()?.document(p.id.uuidString).setData(p.firestoreData) { error in
            if let error { print("🔴 addProduct failed: \(error.localizedDescription)") }
        }
    }

    func updateProduct(_ p: Product) {
        productsRef()?.document(p.id.uuidString).setData(p.firestoreData) { error in
            if let error { print("🔴 updateProduct failed: \(error.localizedDescription)") }
        }
    }

    func deleteProduct(_ p: Product) {
        productsRef()?.document(p.id.uuidString).delete { error in
            if let error { print("🔴 deleteProduct failed: \(error.localizedDescription)") }
        }
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

    // MARK: - Settings (stored locally — per device preference)

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "dk_settings")
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "dk_settings"),
           let s    = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = s
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

    // MARK: - Private

    private func seedDefaults() {
        Category.defaults.forEach { addCategory($0) }
    }
}
