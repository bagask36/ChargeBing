import SwiftUI
import MapKit

struct SessionsListView: View {
    @State private var viewModel = SessionsViewModel()
    @State private var searchText: String = ""
    @State private var showAddSessionSheet = false
    @State private var selectedSessionForDetail: ChargingSession?
    @State private var sessionToDelete: ChargingSession?
    @State private var showDeleteConfirmation = false

    private var filteredSessions: [ChargingSession] {
        let list = viewModel.sessions
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return list }

        return list.filter { session in
            let stationName = session.station?.name.lowercased() ?? ""
            let operatorName = session.station?.operatorName?.lowercased() ?? ""
            let carName = session.evModel?.fullName.lowercased() ?? ""
            let notes = session.notes?.lowercased() ?? ""
            return stationName.contains(query) || operatorName.contains(query) || carName.contains(query) || notes.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Hero Summary Card
                    if !viewModel.sessions.isEmpty {
                        SessionsSummaryHeader(
                            totalCount: viewModel.sessions.count,
                            totalKwh: viewModel.totalKwh,
                            totalCost: viewModel.totalCost,
                            avgCostPerKwh: viewModel.averageCostPerKwh
                        )
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    // MARK: - Mode Filter Chips
                    SessionModeFilterBar(
                        selectedFilter: $viewModel.modeFilter,
                        allCount: viewModel.sessions.count,
                        dcCount: viewModel.sessions.filter { $0.chargingMode == "DC" }.count,
                        acCount: viewModel.sessions.filter { $0.chargingMode == "AC" }.count
                    ) { newFilter in
                        Task { await viewModel.fetchSessions() }
                    }

                    // MARK: - Sessions List / Status Content
                    if viewModel.isLoading && viewModel.sessions.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color.emerald)
                            Text("Memuat sesi pengisian...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if filteredSessions.isEmpty {
                        SessionsEmptyView(
                            isSearching: !searchText.isEmpty,
                            modeFilter: viewModel.modeFilter,
                            onAddTapped: { showAddSessionSheet = true }
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredSessions) { session in
                                SessionCardView(
                                    session: session,
                                    onTap: { selectedSessionForDetail = session },
                                    onDelete: {
                                        sessionToDelete = session
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Sesi Pengisian")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Cari SPKLU, operator, atau mobil...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSessionSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.subheadline.bold())
                            Text("Catat Sesi")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(Color.emerald)
                    }
                }
            }
            .refreshable {
                await viewModel.fetchSessions()
            }
            .task {
                await viewModel.fetchSessions()
            }
            .sheet(isPresented: $showAddSessionSheet) {
                AddSessionSheet(
                    onSessionSaved: {
                        Task { await viewModel.fetchSessions() }
                    }
                )
            }
            .sheet(item: $selectedSessionForDetail) { session in
                SessionDetailSheet(
                    session: session,
                    onDelete: {
                        selectedSessionForDetail = nil
                        sessionToDelete = session
                        showDeleteConfirmation = true
                    }
                )
            }
            .confirmationDialog(
                "Hapus Sesi Pengisian?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Hapus Sesi", role: .destructive) {
                    if let session = sessionToDelete {
                        Task { await viewModel.deleteSession(id: session.id) }
                    }
                }
                Button("Batal", role: .cancel) {
                    sessionToDelete = nil
                }
            } message: {
                Text("Tindakan ini akan menghapus riwayat pengisian dan metrik kWh terkait secara permanen.")
            }
        }
    }
}

// MARK: - Summary Header Component
private struct SessionsSummaryHeader: View {
    let totalCount: Int
    let totalKwh: Double
    let totalCost: Double
    let avgCostPerKwh: Double?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ringkasan Riwayat")
                        .font(.caption.bold())
                        .foregroundStyle(Color.emerald)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("\(totalCount) Sesi Pengisian")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "bolt.batteryblock.fill")
                    .font(.title2)
                    .foregroundStyle(Color.emerald)
                    .padding(10)
                    .background(Color.emerald.opacity(0.12))
                    .clipShape(Circle())
            }

            Divider()
                .overlay(Color.primary.opacity(0.06))

            HStack(spacing: 12) {
                SummaryMetricItem(
                    title: "Total Energi",
                    value: Formatters.kwh(totalKwh),
                    icon: "bolt.fill",
                    tint: Color.emerald
                )

                Divider()
                    .frame(height: 36)

                SummaryMetricItem(
                    title: "Total Biaya",
                    value: Formatters.currency(totalCost),
                    icon: "banknote.fill",
                    tint: .orange
                )

                if let avg = avgCostPerKwh {
                    Divider()
                        .frame(height: 36)

                    SummaryMetricItem(
                        title: "Rata-rata/kWh",
                        value: Formatters.currency(avg),
                        icon: "gauge.with.needle.fill",
                        tint: .blue
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.emerald.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SummaryMetricItem: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Filter Bar
private struct SessionModeFilterBar: View {
    @Binding var selectedFilter: String
    let allCount: Int
    let dcCount: Int
    let acCount: Int
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SessionFilterChip(
                    title: "Semua",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedFilter == "ALL",
                    badge: "\(allCount)"
                ) {
                    selectedFilter = "ALL"
                    onSelect("ALL")
                }

                SessionFilterChip(
                    title: "DC Fast",
                    icon: "bolt.fill",
                    isSelected: selectedFilter == "DC",
                    badge: "\(dcCount)",
                    tint: Color.emerald
                ) {
                    selectedFilter = "DC"
                    onSelect("DC")
                }

                SessionFilterChip(
                    title: "AC Normal",
                    icon: "powerplug.fill",
                    isSelected: selectedFilter == "AC",
                    badge: "\(acCount)",
                    tint: .blue
                ) {
                    selectedFilter = "AC"
                    onSelect("AC")
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct SessionFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var badge: String? = nil
    var tint: Color = Color.emerald
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.bold())

                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if let badge = badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? tint : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: isSelected ? tint.opacity(0.25) : Color.clear, radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Modern Session Card
struct SessionCardView: View {
    let session: ChargingSession
    let onTap: () -> Void
    let onDelete: () -> Void

    var isDC: Bool {
        session.chargingMode == "DC"
    }

    var durationText: String? {
        Formatters.duration(from: session.startedAt, to: session.endedAt)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // Top Row: Badges & Relative Date
                HStack(alignment: .center, spacing: 8) {
                    // Mode Tag
                    HStack(spacing: 5) {
                        Image(systemName: isDC ? "bolt.fill" : "powerplug.fill")
                            .font(.caption.bold())
                        Text(isDC ? "DC Fast Charging" : "AC Normal")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isDC ? Color.emerald.opacity(0.14) : Color.blue.opacity(0.14))
                    .foregroundStyle(isDC ? Color.emerald : Color.blue)
                    .clipShape(Capsule())

                    if let conn = session.connector {
                        Text("\(conn.plugType) · \(Int(conn.powerKw)) kW")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(Formatters.relativeTime(session.startedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Station Info & Car Model
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.station?.name ?? "Stasiun SPKLU")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 8) {
                        if let op = session.station?.operatorName, !op.isEmpty {
                            Text(op)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        if let car = session.evModel {
                            HStack(spacing: 4) {
                                Image(systemName: "car.side.fill")
                                    .font(.caption2)
                                Text(car.fullName)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Metric Pills (3 Columns)
                HStack(spacing: 8) {
                    MetricCardPill(
                        label: "Energi",
                        value: Formatters.kwh(session.kwh),
                        icon: "bolt.badge.checkmark.fill",
                        tint: Color.emerald
                    )

                    MetricCardPill(
                        label: "Biaya",
                        value: Formatters.currency(session.cost),
                        icon: "banknote.fill",
                        tint: .orange
                    )

                    if let dur = durationText {
                        MetricCardPill(
                            label: "Durasi",
                            value: dur,
                            icon: "clock.fill",
                            tint: .blue
                        )
                    }
                }

                // Battery SoC Progress Gauge (if available)
                if let start = session.socStart, let end = session.socEnd {
                    SessionBatteryGauge(startSoC: start, endSoC: end)
                }

                // Optional Notes Preview
                if let notes = session.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "text.bubble.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.emerald)
                            .padding(.top, 1)

                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Hapus Sesi", systemImage: "trash")
            }
        }
    }
}

// MARK: - Metric Card Pill
private struct MetricCardPill: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Battery Gauge Component
private struct SessionBatteryGauge: View {
    let startSoC: Int
    let endSoC: Int

    var gain: Int {
        max(0, endSoC - startSoC)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "battery.75percent")
                        .font(.caption.bold())
                        .foregroundStyle(Color.emerald)
                    Text("Pengisian Baterai")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(startSoC)%")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                    Text("\(endSoC)%")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)

                    if gain > 0 {
                        Text("+\(gain)%")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.emerald)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.emerald.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            // Visual Progress Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Total Track (0 - 100%)
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 7)

                    // Existing SoC portion (light muted)
                    let startWidth = geo.size.width * CGFloat(min(100, max(0, startSoC))) / 100.0
                    let endWidth = geo.size.width * CGFloat(min(100, max(0, endSoC))) / 100.0
                    let chargeWidth = max(0, endWidth - startWidth)

                    HStack(spacing: 0) {
                        Capsule()
                            .fill(Color.emerald.opacity(0.35))
                            .frame(width: startWidth, height: 7)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.emerald, Color.emerald.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: chargeWidth, height: 7)
                    }
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Empty View Component
private struct SessionsEmptyView: View {
    let isSearching: Bool
    let modeFilter: String
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.emerald.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: isSearching ? "magnifyingglass" : "bolt.badge.clock.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.emerald)
            }
            .padding(.top, 20)

            VStack(spacing: 6) {
                Text(isSearching ? "Tidak Ditemukan" : "Belum Ada Sesi Pengisian")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text(
                    isSearching
                    ? "Coba kata kunci pencarian stasiun atau mobil yang berbeda."
                    : "Mulai catat setiap sesi pengisian mobil listrik Anda untuk melacak biaya, efisiensi energi kWh, dan riwayat baterai."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            if !isSearching {
                Button(action: onAddTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.headline)
                        Text("Catat Sesi Sekarang")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.emerald)
                    .clipShape(Capsule())
                    .shadow(color: Color.emerald.opacity(0.35), radius: 8, y: 4)
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Session Detail Sheet
struct SessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: ChargingSession
    let onDelete: () -> Void

    var isDC: Bool {
        session.chargingMode == "DC"
    }

    var costPerKwh: Double? {
        guard let cost = session.cost, session.kwh > 0 else { return nil }
        return cost / session.kwh
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isDC ? Color.emerald.opacity(0.15) : Color.blue.opacity(0.15))
                                .frame(width: 72, height: 72)

                            Image(systemName: isDC ? "bolt.fill" : "powerplug.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(isDC ? Color.emerald : Color.blue)
                        }

                        Text(session.station?.name ?? "Stasiun SPKLU")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Text(isDC ? "DC Fast Charging" : "AC Normal")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(isDC ? Color.emerald.opacity(0.15) : Color.blue.opacity(0.15))
                                .foregroundStyle(isDC ? Color.emerald : Color.blue)
                                .clipShape(Capsule())

                            if let op = session.station?.operatorName {
                                Text(op)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.08))
                                    .foregroundStyle(.secondary)
                                    .clipShape(Capsule())
                            }
                        }

                        if let address = session.station?.address, !address.isEmpty {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        if let station = session.station {
                            Button {
                                openMapNavigation(to: station)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                    Text("Buka di Apple Maps")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(Color.emerald)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.emerald.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Key Metrics Details Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Metrik Pengisian")
                            .font(.headline)

                        VStack(spacing: 12) {
                            DetailInfoRow(
                                title: "Energi Terisi",
                                value: Formatters.kwh(session.kwh),
                                icon: "bolt.badge.checkmark.fill",
                                tint: Color.emerald
                            )

                            DetailInfoRow(
                                title: "Total Biaya",
                                value: Formatters.currency(session.cost),
                                icon: "banknote.fill",
                                tint: .orange
                            )

                            if let rate = costPerKwh {
                                DetailInfoRow(
                                    title: "Tarif per kWh",
                                    value: "\(Formatters.currency(rate)) / kWh",
                                    icon: "gauge.with.needle.fill",
                                    tint: .blue
                                )
                            }

                            if let duration = Formatters.duration(from: session.startedAt, to: session.endedAt) {
                                DetailInfoRow(
                                    title: "Estimasi Durasi",
                                    value: duration,
                                    icon: "clock.fill",
                                    tint: .purple
                                )
                            }

                            DetailInfoRow(
                                title: "Waktu Mulai",
                                value: Formatters.dateTime(session.startedAt),
                                icon: "calendar",
                                tint: .secondary
                            )

                            if let ended = session.endedAt {
                                DetailInfoRow(
                                    title: "Waktu Selesai",
                                    value: Formatters.dateTime(ended),
                                    icon: "calendar.badge.checkmark",
                                    tint: .secondary
                                )
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Battery SoC Card (if available)
                    if let start = session.socStart, let end = session.socEnd {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status Baterai (SoC)")
                                .font(.headline)

                            SessionBatteryGauge(startSoC: start, endSoC: end)

                            HStack {
                                Text("Awal: \(start)%")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Akhir: \(end)% (+\(max(0, end - start))%)")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.emerald)
                            }
                        }
                        .padding(18)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // Vehicle & Connector Info Card
                    if session.evModel != nil || session.connector != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Kendaraan & Spesifikasi Colokan")
                                .font(.headline)

                            if let car = session.evModel {
                                DetailInfoRow(
                                    title: "Mobil Listrik",
                                    value: car.fullName,
                                    icon: "car.side.fill",
                                    tint: Color.emerald
                                )
                                DetailInfoRow(
                                    title: "Kapasitas Baterai",
                                    value: "\(String(format: "%.1f", car.batteryCapacityKwh)) kWh",
                                    icon: "battery.100percent",
                                    tint: .blue
                                )
                            }

                            if let conn = session.connector {
                                DetailInfoRow(
                                    title: "Tipe Colokan",
                                    value: "\(conn.currentType) \(conn.plugType)",
                                    icon: "powerplug.fill",
                                    tint: .orange
                                )
                                DetailInfoRow(
                                    title: "Daya Charger",
                                    value: "\(Int(conn.powerKw)) kW",
                                    icon: "speedometer",
                                    tint: .purple
                                )
                            }
                        }
                        .padding(18)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // Notes (if any)
                    if let notes = session.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Catatan Pengguna")
                                .font(.headline)

                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // Delete Action Button
                    Button(role: .destructive, action: onDelete) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Hapus Riwayat Sesi Ini")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Detail Sesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                        .font(.subheadline.bold())
                }
            }
        }
    }

    private func openMapNavigation(to station: Station) {
        let location = CLLocation(latitude: station.latitude, longitude: station.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = station.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}
