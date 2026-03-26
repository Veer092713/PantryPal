import Foundation
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

// MARK: - Intent Error

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn
    case productNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSignedIn:
            return "Please open PantryPilot and sign in first, then try again."
        case .productNotFound(let name):
            return "I couldn't find \(name) in your pantry."
        }
    }
}

// MARK: - Pantry Intent Store

/// Lightweight Firestore accessor used exclusively by App Intents.
/// App Intents run in-process (iOS 16+), so Firebase Auth state is already available.
final class PantryIntentStore {

    static let shared = PantryIntentStore()

    private let db: Firestore

    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        db = Firestore.firestore()
    }

    private var userID: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Products

    func addProduct(_ product: Product) async throws {
        guard let uid = userID else { throw IntentError.notSignedIn }
        try await db
            .collection("users").document(uid)
            .collection("products").document(product.id.uuidString)
            .setData(product.firestoreData)
    }

    /// Returns the first product whose name contains `query` (case-insensitive).
    func findProduct(named query: String) async throws -> Product? {
        guard let uid = userID else { throw IntentError.notSignedIn }
        let snapshot = try await db
            .collection("users").document(uid)
            .collection("products")
            .getDocuments()
        return snapshot.documents
            .compactMap { Product(from: $0.data()) }
            .first { $0.name.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Shopping Items

    func addShoppingItem(_ item: ShoppingItem) async throws {
        guard let uid = userID else { throw IntentError.notSignedIn }
        try await db
            .collection("users").document(uid)
            .collection("shoppingItems").document(item.id.uuidString)
            .setData(item.firestoreData)
    }

    /// Returns the first shopping item whose name contains `query` (case-insensitive).
    func findShoppingItem(named query: String) async throws -> ShoppingItem? {
        guard let uid = userID else { throw IntentError.notSignedIn }
        let snapshot = try await db
            .collection("users").document(uid)
            .collection("shoppingItems")
            .getDocuments()
        return snapshot.documents
            .compactMap { ShoppingItem(from: $0.data()) }
            .first { $0.name.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Categories

    /// Returns the "Pantry" category, or the first category available, or the built-in default.
    func defaultCategory() async throws -> Category {
        guard let uid = userID else { throw IntentError.notSignedIn }
        let snapshot = try await db
            .collection("users").document(uid)
            .collection("categories")
            .getDocuments()
        let categories = snapshot.documents.compactMap { Category(from: $0.data()) }
        return categories.first { $0.name.lowercased() == "pantry" }
            ?? categories.first
            ?? Category.defaults[0]
    }
}
