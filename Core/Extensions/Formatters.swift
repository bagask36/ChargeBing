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

    static func parseDate(_ isoString: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFormatter.date(from: isoString) { return d }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: isoString)
    }

    static func dateTime(_ isoString: String) -> String {
        guard let validDate = parseDate(isoString) else { return isoString }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "id_ID")
        displayFormatter.dateFormat = "d MMM yyyy, HH:mm"
        return displayFormatter.string(from: validDate)
    }

    static func relativeTime(_ isoString: String) -> String {
        guard let date = parseDate(isoString) else { return isoString }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func duration(from startIso: String, to endIso: String?) -> String? {
        guard let start = parseDate(startIso),
              let endStr = endIso,
              let end = parseDate(endStr) else {
            return nil
        }
        let interval = max(0, end.timeIntervalSince(start))
        let minutes = Int(interval / 60)
        if minutes < 1 {
            return "< 1 mnt"
        } else if minutes < 60 {
            return "\(minutes) mnt"
        } else {
            let hours = minutes / 60
            let rem = minutes % 60
            return rem == 0 ? "\(hours) jam" : "\(hours)j \(rem)m"
        }
    }
}

