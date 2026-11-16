import Foundation

enum Formatters {
    static func currency(_ amount: Double?) -> String {
        guard let amount = amount else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "Rp \(Int(amount))"
    }

    static func kwh(_ value: Double) -> String {
        return String(format: "%.2f kWh", value)
    }

    static func distance(_ km: Double?) -> String {
        guard let km = km else { return "-" }
        if km < 1.0 {
            return String(format: "%.0f m", km * 1000)
        }
        return String(format: "%.1f km", km)
    }

    static func dateTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: isoString)

        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }

        guard let validDate = date else { return isoString }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "id_ID")
        displayFormatter.dateFormat = "d MMM yyyy, HH:mm"
        return displayFormatter.string(from: validDate)
    }

    static func relativeTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: isoString) else { return isoString }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

