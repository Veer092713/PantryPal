import Foundation
import UserNotifications
import Observation

@Observable
final class NotificationManager {

    private let center = UNUserNotificationCenter.current()

    func scheduleAll(products: [Product], settings: AppSettings = AppSettings()) {
        guard settings.notificationsEnabled else { return }
        center.removeAllPendingNotificationRequests()

        let threshold = settings.notifyDaysBefore
        let expiring  = products.filter { $0.daysUntilExpiry >= 0 && $0.daysUntilExpiry <= threshold }
        guard !expiring.isEmpty else { return }

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

        for product in products {
            scheduleExpiryNotification(for: product)
        }
    }

    func scheduleExpiryNotification(for product: Product) {
        let content       = UNMutableNotificationContent()
        content.title     = "⏰ Expires Today"
        content.body      = "\(product.name) expires today! Use it now."
        content.sound     = .default

        var dc            = Calendar.current.dateComponents([.year, .month, .day], from: product.expiryDate)
        dc.hour           = 8
        dc.minute         = 0
        let trigger       = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
        let request       = UNNotificationRequest(identifier: "dk_\(product.id.uuidString)",
                                                  content: content,
                                                  trigger: trigger)
        center.add(request)
    }

    func cancelNotification(for product: Product) {
        center.removePendingNotificationRequests(withIdentifiers: ["dk_\(product.id.uuidString)"])
    }
}
