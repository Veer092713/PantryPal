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
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Firestore Serialization: Product
extension Product {

    /// Converts a Product to a Firestore-compatible dictionary.
    /// Note: imageData is intentionally excluded (use Firebase Storage for image sync).
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id":         id.uuidString,
            "name":       name,
            "brand":      brand,
            "categoryID": categoryID.uuidString,
            "expiryDate": Timestamp(date: expiryDate),
            "addedDate":  Timestamp(date: addedDate),
            "notes":      notes
        ]
        if let barcode { data["barcode"] = barcode }
        return data
    }

    /// Failable initializer from a raw Firestore document dictionary.
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
        self.notes      = data["notes"]   as? String ?? ""
        self.barcode    = data["barcode"] as? String
        self.imageData  = nil   // not stored in Firestore
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
