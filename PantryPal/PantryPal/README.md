# PantryPal 🗓️

Track food expiry dates, reduce waste, and get notified before items go bad.

---

## Project Structure

```
DateKeeper/
├── DateKeeperApp.swift       # App entry point, notification permission request
├── Models.swift              # Product, Category, ExpiryStatus, AppSettings
├── ProductStore.swift        # SwiftData persistence layer (= Android Room equivalent)
├── NotificationManager.swift # Local notification scheduling
├── ContentView.swift         # Root TabView + in-app expiry banner
├── HomeView.swift            # Dashboard with big SCAN button + status cards
├── ScannerView.swift         # DataScannerViewController wrapper (barcode + text)
├── AddProductView.swift      # Add/edit product form + scan sheet
├── ProductListView.swift     # Searchable, sortable list + product detail
├── CategoriesView.swift      # Category grid + add custom category
└── SettingsView.swift        # Notification settings + stats
```

---

## Setup in Xcode

### 1. Create the Project
- Open Xcode → New Project → **App**
- Product Name: `DateKeeper`
- Interface: **SwiftUI**
- Language: **Swift**
- ✅ Check **"Use SwiftData"** (requires iOS 17+)

### 2. Add All Files
Drag all `.swift` files from this folder into your Xcode project.  
Delete the auto-generated `Item.swift` (SwiftData placeholder).

### 3. Required Permissions (Info.plist)
Add these keys to your `Info.plist`:

| Key | Value |
|-----|-------|
| `NSCameraUsageDescription` | "DateKeeper uses the camera to scan product barcodes and expiry dates." |
| `NSPhotoLibraryUsageDescription` | "DateKeeper can save product photos from your library." |

### 4. Capabilities
In your target's **Signing & Capabilities**, add:
- ✅ **Push Notifications** (for local notifications)

### 5. Minimum Deployment Target
Set to **iOS 17.0** (required for SwiftData + DataScannerViewController).

---

## Architecture

| Layer | iOS Equivalent | Role |
|-------|---------------|------|
| Database | **SwiftData** (SQLite-backed ORM) | Replaces Android Room |
| Models | `@Model` classes | Replaces `@Entity` |
| Store | `ModelContainer` / `ModelContext` | Replaces DAO + Repository |
| Notifications | `UserNotifications` framework | Local push scheduling |
| Scanner | `DataScannerViewController` (VisionKit) | Barcode + text OCR |

---

## Features

### 🔍 Scanning
- Tap the big **Scan** button on the home screen
- Uses `DataScannerViewController` for real-time barcode and text detection
- Auto-captures on barcode detection; tap-to-capture for text
- Scanned barcode and detected text pre-fill the Add Product form

### 🗄️ Database (SwiftData)
- Products and categories stored in a local SQLite database via SwiftData
- Full CRUD: create, read, update, delete
- Sorted by expiry date by default

### 📦 Categories
- **Pantry**, **Fridge**, **Freezer** built-in
- Add unlimited custom categories with custom icon + color
- Each category shows item count

### 🔔 Notifications
- **Daily digest** at 9 AM listing items expiring within your threshold
- **Per-item notification** on the day of expiry
- Configurable: enable/disable, check interval, days-before threshold
- In-app banner automatically shown for the soonest-expiring item

### 📊 Status Colors
| Status | Trigger | Color |
|--------|---------|-------|
| Expired | Past expiry | 🔴 Red |
| Critical | ≤ 3 days | 🟠 Orange |
| Warning | 4–7 days | 🟡 Yellow |
| Good | 8+ days | 🟢 Green |

---

## Extending the App

### Add barcode lookup (Open Food Facts)
```swift
// In AddProductView, after a barcode is scanned:
let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!
let (data, _) = try await URLSession.shared.data(from: url)
// Parse product name from JSON response
```

### Add widget (WidgetKit)
Create a widget extension that reads the same SwiftData store and shows
the most urgently expiring item on the home screen.

### Add iCloud sync
In Signing & Capabilities, add **CloudKit**. Change `ModelConfiguration`
to use `cloudKitContainerIdentifier` for automatic iCloud sync.
