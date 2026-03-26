import AppIntents

struct PantryPilotShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        AppShortcut(
            intent: AddProductIntent(),
            phrases: [
                "Add a product to \(.applicationName)",
                "Add to my pantry in \(.applicationName)",
                "New pantry item in \(.applicationName)",
            ],
            shortTitle: "Add Product",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "Add to shopping list in \(.applicationName)",
                "Add to my shopping list in \(.applicationName)",
                "New shopping item in \(.applicationName)",
            ],
            shortTitle: "Add to Shopping List",
            systemImageName: "cart.badge.plus"
        )

        AppShortcut(
            intent: CheckShoppingListIntent(),
            phrases: [
                "Check my \(.applicationName) shopping list",
                "Is something on my \(.applicationName) shopping list",
            ],
            shortTitle: "Check Shopping List",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: CheckExpiryIntent(),
            phrases: [
                "Check expiry in \(.applicationName)",
                "When does something expire in \(.applicationName)",
            ],
            shortTitle: "Check Expiry",
            systemImageName: "calendar.badge.clock"
        )
    }
}
