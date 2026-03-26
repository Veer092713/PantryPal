import AppIntents

struct PantryPilotShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        // "Hey Siri, add Doritos expiring May 10 2026 in PantryPilot"
        AppShortcut(
            intent: AddProductIntent(),
            phrases: [
                "Add \(\.$productName) to \(.applicationName)",
                "Add \(\.$productName) expiring \(\.$expiryDate) in \(.applicationName)",
                "Add \(\.$productName) to my pantry in \(.applicationName)",
            ],
            shortTitle: "Add Product",
            systemImageName: "plus.circle.fill"
        )

        // "Hey Siri, add milk to the shopping list in PantryPilot"
        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "Add \(\.$itemName) to my shopping list in \(.applicationName)",
                "Add \(\.$itemName) to the shopping list in \(.applicationName)",
                "Add \(\.$itemName) to shopping list in \(.applicationName)",
            ],
            shortTitle: "Add to Shopping List",
            systemImageName: "cart.badge.plus"
        )

        // "Hey Siri, do I have milk in my PantryPilot shopping list"
        AppShortcut(
            intent: CheckShoppingListIntent(),
            phrases: [
                "Do I have \(\.$itemName) in my \(.applicationName) shopping list",
                "Is \(\.$itemName) on my shopping list in \(.applicationName)",
                "Check if \(\.$itemName) is on my \(.applicationName) shopping list",
            ],
            shortTitle: "Check Shopping List",
            systemImageName: "checklist"
        )

        // "Hey Siri, when will my Doritos expire in PantryPilot"
        AppShortcut(
            intent: CheckExpiryIntent(),
            phrases: [
                "When will my \(\.$productName) expire in \(.applicationName)",
                "When does my \(\.$productName) expire in \(.applicationName)",
                "Check expiry of \(\.$productName) in \(.applicationName)",
            ],
            shortTitle: "Check Expiry",
            systemImageName: "calendar.badge.clock"
        )
    }
}
