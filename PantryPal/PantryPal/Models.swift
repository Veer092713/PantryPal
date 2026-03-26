import Foundation
import SwiftUI
@preconcurrency import FirebaseFirestore

// MARK: - Category Model
struct Category: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var colorHex: String

    static let defaults: [Category] = [
        Category(name: "Pantry",  icon: "cabinet",      colorHex: "#F4A261"),
        Category(name: "Fridge",  icon: "refrigerator", colorHex: "#457B9D"),
        Category(name: "Freezer", icon: "snowflake",    colorHex: "#A8DADC"),
    ]

    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Product Model
struct Product: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var brand: String
    var categoryID: UUID
    var expiryDate: Date
    var addedDate: Date = Date()
    var notes: String = ""
    var quantity: Int = 1
    var barcode: String? = nil
    var imageData: Data? = nil     // local only — not synced to Firestore

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }

    var status: ExpiryStatus {
        switch daysUntilExpiry {
        case ..<0:    return .expired
        case 0...3:   return .critical
        case 4...7:   return .warning
        default:      return .good
        }
    }
}

// MARK: - Shopping Item Model
struct ShoppingItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var brand: String = ""
    var quantity: Int = 1
    var addedDate: Date = Date()
    var isPurchased: Bool = false
}

// MARK: - Waste Entry Model
struct WasteEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var productName: String
    var productBrand: String
    var wasWasted: Bool   // true = discarded/threw away, false = consumed/used up
    var date: Date = Date()
}

// MARK: - Expiry Status
enum ExpiryStatus: String, CaseIterable {
    case expired  = "Expired"
    case critical = "Expires Soon"
    case warning  = "Expiring"
    case good     = "Fresh"

    var color: Color {
        switch self {
        case .expired:  return .red
        case .critical: return .orange
        case .warning:  return .yellow
        case .good:     return .green
        }
    }

    var icon: String {
        switch self {
        case .expired:  return "xmark.circle.fill"
        case .critical: return "exclamationmark.triangle.fill"
        case .warning:  return "clock.fill"
        case .good:     return "checkmark.circle.fill"
        }
    }
}

// MARK: - Notification Interval
enum NotificationInterval: String, CaseIterable, Codable {
    case daily  = "Daily"
    case every3 = "Every 3 Days"
    case weekly = "Weekly"

    var days: Int {
        switch self {
        case .daily:  return 1
        case .every3: return 3
        case .weekly: return 7
        }
    }
}

// MARK: - App Settings
struct AppSettings: Codable, Equatable {
    var notificationInterval: NotificationInterval = .daily
    var notifyDaysBefore: Int = 3
    var notificationsEnabled: Bool = true
    var shoppingListNotificationsEnabled: Bool = false
    var shoppingListNotificationInterval: NotificationInterval = .weekly
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { self = .clear; return }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: self = .clear; return
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Haptic Feedback Helper
enum HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Firestore Serialization: Product
extension Product {

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id":         id.uuidString,
            "name":       name,
            "brand":      brand,
            "categoryID": categoryID.uuidString,
            "expiryDate": Timestamp(date: expiryDate),
            "addedDate":  Timestamp(date: addedDate),
            "notes":      notes,
            "quantity":   quantity
        ]
        if let barcode { data["barcode"] = barcode }
        return data
    }

    init?(from data: [String: Any]) {
        guard
            let idStr    = data["id"]         as? String,   let id         = UUID(uuidString: idStr),
            let name     = data["name"]       as? String,
            let brand    = data["brand"]      as? String,
            let catStr   = data["categoryID"] as? String,   let categoryID = UUID(uuidString: catStr),
            let expiryTS = data["expiryDate"] as? Timestamp,
            let addedTS  = data["addedDate"]  as? Timestamp
        else { return nil }

        self.id         = id
        self.name       = name
        self.brand      = brand
        self.categoryID = categoryID
        self.expiryDate = expiryTS.dateValue()
        self.addedDate  = addedTS.dateValue()
        self.notes      = data["notes"]    as? String ?? ""
        self.quantity   = data["quantity"] as? Int    ?? 1
        self.barcode    = data["barcode"]  as? String
        self.imageData  = nil
    }
}

// MARK: - Firestore Serialization: Category
extension Category {

    var firestoreData: [String: Any] {
        [
            "id":       id.uuidString,
            "name":     name,
            "icon":     icon,
            "colorHex": colorHex
        ]
    }

    init?(from data: [String: Any]) {
        guard
            let idStr    = data["id"]       as? String, let id = UUID(uuidString: idStr),
            let name     = data["name"]     as? String,
            let icon     = data["icon"]     as? String,
            let colorHex = data["colorHex"] as? String
        else { return nil }

        self.id       = id
        self.name     = name
        self.icon     = icon
        self.colorHex = colorHex
    }
}

// MARK: - Firestore Serialization: ShoppingItem
extension ShoppingItem {

    var firestoreData: [String: Any] {
        [
            "id":          id.uuidString,
            "name":        name,
            "brand":       brand,
            "quantity":    quantity,
            "addedDate":   Timestamp(date: addedDate),
            "isPurchased": isPurchased
        ]
    }

    init?(from data: [String: Any]) {
        guard
            let idStr   = data["id"]   as? String, let id = UUID(uuidString: idStr),
            let name    = data["name"] as? String,
            let addedTS = data["addedDate"] as? Timestamp
        else { return nil }

        self.id          = id
        self.name        = name
        self.brand       = data["brand"]       as? String ?? ""
        self.quantity    = data["quantity"]    as? Int    ?? 1
        self.addedDate   = addedTS.dateValue()
        self.isPurchased = data["isPurchased"] as? Bool   ?? false
    }
}

// MARK: - Firestore Serialization: WasteEntry
extension WasteEntry {

    var firestoreData: [String: Any] {
        [
            "id":           id.uuidString,
            "productName":  productName,
            "productBrand": productBrand,
            "wasWasted":    wasWasted,
            "date":         Timestamp(date: date)
        ]
    }

    init?(from data: [String: Any]) {
        guard
            let idStr       = data["id"]          as? String, let id = UUID(uuidString: idStr),
            let productName = data["productName"]  as? String,
            let wasWasted   = data["wasWasted"]    as? Bool,
            let dateTS      = data["date"]         as? Timestamp
        else { return nil }

        self.id           = id
        self.productName  = productName
        self.productBrand = data["productBrand"] as? String ?? ""
        self.wasWasted    = wasWasted
        self.date         = dateTS.dateValue()
    }
}
