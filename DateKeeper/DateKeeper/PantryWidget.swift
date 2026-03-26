import WidgetKit
import SwiftUI

// MARK: - Shared Data Model (must match ProductStore.writeWidgetData)

private let appGroupID = "group.com.pantrypal.shared"
private let dataKey    = "pantrypal.expiring"

struct ExpiringItem: Identifiable {
    let id     = UUID()
    let name:     String
    let daysLeft: Int
    let status:   String

    var statusColor: Color {
        switch status {
        case "Expired":      return .red
        case "Expires Soon": return .orange
        case "Expiring":     return .yellow
        default:             return .green
        }
    }

    var statusIcon: String {
        switch status {
        case "Expired":      return "xmark.circle.fill"
        case "Expires Soon": return "exclamationmark.triangle.fill"
        case "Expiring":     return "clock.fill"
        default:             return "checkmark.circle.fill"
        }
    }

    var expiryLabel: String {
        switch daysLeft {
        case ..<0: return "Expired"
        case 0:    return "Today"
        case 1:    return "Tomorrow"
        default:   return "\(daysLeft)d"
        }
    }
}

private func loadItems() -> [ExpiringItem] {
    guard
        let defaults = UserDefaults(suiteName: appGroupID),
        let data     = defaults.data(forKey: dataKey),
        let raw      = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }

    return raw.compactMap { dict -> ExpiringItem? in
        guard let name = dict["name"] as? String else { return nil }
        let daysLeft = dict["daysLeft"] as? Int    ?? 0
        let status   = dict["status"]   as? String ?? "Fresh"
        return ExpiringItem(name: name, daysLeft: daysLeft, status: status)
    }
}

// MARK: - Timeline Entry

struct PantryEntry: TimelineEntry {
    let date:  Date
    let items: [ExpiringItem]
}

// MARK: - Provider

struct PantryProvider: TimelineProvider {
    func placeholder(in context: Context) -> PantryEntry {
        PantryEntry(date: Date(), items: [
            ExpiringItem(name: "Milk",     daysLeft: 1, status: "Expires Soon"),
            ExpiringItem(name: "Yoghurt",  daysLeft: 3, status: "Expires Soon"),
            ExpiringItem(name: "Cheddar",  daysLeft: 6, status: "Expiring"),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (PantryEntry) -> Void) {
        completion(PantryEntry(date: Date(), items: loadItems()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PantryEntry>) -> Void) {
        let entry    = PantryEntry(date: Date(), items: loadItems())
        // Refresh at next midnight so counts stay accurate
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct PantryWidgetEntryView: View {
    var entry: PantryEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.items.isEmpty {
            emptyView
        } else {
            switch family {
            case .systemSmall:  smallView
            case .systemMedium: mediumView
            default:            mediumView
            }
        }
    }

    // MARK: Empty State
    var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(.teal)
            Text("All Fresh!")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Nothing expiring soon")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.teal.opacity(0.06), for: .widget)
    }

    // MARK: Small (1 item + count badge)
    var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.teal)
                    .font(.caption.bold())
                Text("PantryPal")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                Spacer()
            }

            Spacer()

            if let first = entry.items.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: first.statusIcon)
                            .foregroundStyle(first.statusColor)
                            .font(.caption2)
                        Text(first.expiryLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(first.statusColor)
                    }
                    Text(first.name)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("\(entry.items.count) expiring")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.teal.opacity(0.06), for: .widget)
    }

    // MARK: Medium (up to 3 items)
    var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.teal)
                    .font(.caption.bold())
                Text("Expiring Soon")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                Spacer()
                Text("\(entry.items.count) item\(entry.items.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(entry.items.prefix(3)) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.statusIcon)
                        .foregroundStyle(item.statusColor)
                        .font(.caption)
                        .frame(width: 16)

                    Text(item.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    Text(item.expiryLabel)
                        .font(.caption.bold())
                        .foregroundStyle(item.statusColor)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(.teal.opacity(0.06), for: .widget)
    }
}

// MARK: - Widget Configuration

@main
struct PantryWidget: Widget {
    let kind = "PantryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PantryProvider()) { entry in
            PantryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PantryPal")
        .description("See items expiring soon in your pantry.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
