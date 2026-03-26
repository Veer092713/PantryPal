import Foundation
import UserNotifications
import Observation

@Observable
final class NotificationManager {

    // MARK: - Singleton
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Schedule All (digest + per-product)

    func scheduleAll(products: [Product], settings: AppSettings = AppSettings()) {
        guard settings.notificationsEnabled else {
            center.removeAllPendingNotificationRequests()
            return
        }
        center.removeAllPendingNotificationRequests()

        let threshold = settings.notifyDaysBefore
        let expiring  = products.filter { $0.daysUntilExpiry >= 0 && $0.daysUntilExpiry <= threshold }
        guard !expiring.isEmpty else { return }

        // Digest notification at 9am
        let content         = UNMutableNotificationContent()
        content.title       = "🛒 PantryPal"
        content.badge       = NSNumber(value: expiring.count)
        content.sound       = .default

        if expiring.count == 1 {
            let p = expiring[0]
            content.body = "\(p.name) expires in \(p.daysUntilExpiry) day(s). Time to use it!"
        } else {
            content.body = "You have \(expiring.count) items expiring within \(threshold) days!"
        }

        var dc      = DateComponents()
        dc.hour     = 9
        dc.minute   = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: "dk_digest", content: content, trigger: trigger)
        center.add(request)

        // Per-product notifications
        for product in products {
            scheduleExpiryNotification(for: product, settings: settings)
        }
    }

    // MARK: - Per-Product Expiry Notification

    func scheduleExpiryNotification(for product: Product, settings: AppSettings = AppSettings()) {
        guard settings.notificationsEnabled else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "⏰ Expires Today"
        content.body      = "\(product.name) expires today! Use it now."
        content.sound     = .default

        // Fire at 9am on expiry date (consistent with digest time)
        var dc            = Calendar.current.dateComponents([.year, .month, .day], from: product.expiryDate)
        dc.hour           = 9
        dc.minute         = 0
        let trigger       = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
        let request       = UNNotificationRequest(identifier: "dk_\(product.id.uuidString)",
                                                  content: content,
                                                  trigger: trigger)
        center.add(request)
    }

    // MARK: - Cancel Notification

    func cancelNotification(for product: Product) {
        center.removePendingNotificationRequests(withIdentifiers: ["dk_\(product.id.uuidString)"])
    }

    // MARK: - Shopping List Reminder

    func scheduleShoppingListReminder(items: [ShoppingItem], settings: AppSettings) {
        center.removePendingNotificationRequests(withIdentifiers: ["pp_shopping_reminder"])

        guard settings.shoppingListNotificationsEnabled else { return }
        let pending = items.filter { !$0.isPurchased }
        guard !pending.isEmpty else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "🛒 Shopping List"
        content.body      = pending.count == 1
            ? "Don't forget — \(pending[0].name) is on your shopping list!"
            : "You have \(pending.count) items on your shopping list. Time to restock!"
        content.sound     = .default

        let interval = TimeInterval(settings.shoppingListNotificationInterval.days * 24 * 60 * 60)
        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request  = UNNotificationRequest(identifier: "pp_shopping_reminder", content: content, trigger: trigger)
        center.add(request)
    }
}
