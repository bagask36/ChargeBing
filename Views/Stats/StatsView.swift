import SwiftUI
import Charts

struct StatsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = StatsViewModel()
    @State private var showLogoutConfirmation = false
    @State private var showEditProfileSheet = false
    @State private var chartMetric: ChartMetricType = .kwh

    enum ChartMetricType: String, CaseIterable, Identifiable {
        case kwh = "Energi (kWh)"
        case cost = "Biaya (Rp)"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - User Profile & Vehicle Header
                    if let user = authVM.currentUser {
                        UserProfileHeaderCard(
                            user: user,
                            onEditTapped: { showEditProfileSheet = true },
                            onLogoutTapped: { showLogoutConfirmation = true }
                        )
                        .padding(.horizontal)
                    }

                    if viewModel.isLoading && viewModel.stats == nil {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color.emerald)
                            Text("Mengalkulasi statistik pengisian...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if let stats = viewModel.stats {
                        // MARK: - Hero All-Time Metrics
                        AllTimeMetricsSection(stats: stats.allTime)
                            .padding(.horizontal)

                        // MARK: - Monthly Trend Chart (if available)
                        if let monthly = stats.monthly, !monthly.isEmpty {
                            MonthlyTrendChartCard(
                                monthly: monthly,
                                selectedMetric: $chartMetric
                            )
                            .padding(.horizontal)
                        }

                        // MARK: - Mode Comparison (DC vs AC)
                        ModeComparisonSection(allTime: stats.allTime)
                            .padding(.horizontal)

                        // MARK: - Current Month Snapshot
                        CurrentMonthSnapshotCard(monthStats: stats.currentMonth)
                            .padding(.horizontal)

                        // MARK: - Eco & Fuel Savings Insight
                        EcoSavingsInsightCard(totalKwh: stats.allTime.totalKwh, totalCost: stats.allTime.totalCost)
                            .padding(.horizontal)

                        // MARK: - App & Connection Info
                        AppInfoSection(
                            onEditProfileTapped: { showEditProfileSheet = true },
                            onLogoutTapped: { showLogoutConfirmation = true }
                        )
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Statistik & Akun")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.fetchStats()
                await authVM.fetchProfile()
            }
            .task {
                await viewModel.fetchStats()
            }
            .confirmationDialog("Keluar Akun", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Keluar Akun", role: .destructive) {
                    Task { await authVM.logout() }
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Apakah Anda yakin ingin keluar dari akun ChargeBing?")
            }
            .sheet(isPresented: $showEditProfileSheet) {
                EditProfileSheet()
            }
        }
    }
}

// MARK: - User Profile Header Card
private struct UserProfileHeaderCard: View {
    let user: User
    let onEditTapped: () -> Void
    let onLogoutTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Top Row: Avatar, Identity & Actions
            HStack(alignment: .top, spacing: 14) {
                // Circular Avatar with edit badge
                Button(action: onEditTapped) {
                    ZStack(alignment: .bottomTrailing) {
                        UserAvatarView(
                            avatarUrl: user.avatarUrl,
                            name: user.name,
                            size: 68,
                            showBorder: true
                        )

                        // Subtle Edit Pen Badge
                        Circle()
                            .fill(Color.emerald)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 2)
                            .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)

                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.name)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.emerald)
                    }

                    Text(user.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.emerald)
                                .frame(width: 6, height: 6)
                            Text("Pengemudi EV Aktif")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.emerald)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.emerald.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Logout button
                Button(action: onLogoutTapped) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .frame(width: 34, height: 34)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Middle Section: Vehicle Pill / Card
            if let car = user.evModel {
                Button(action: onEditTapped) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.emerald.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.emerald)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(car.fullName)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)

                            HStack(spacing: 8) {
                                Label("\(String(format: "%.1f", car.batteryCapacityKwh)) kWh", systemImage: "battery.100percent")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.emerald)

                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Label("\(car.rangeKm) km Range", systemImage: "road.lanes")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onEditTapped) {
                    HStack(spacing: 10) {
                        Image(systemName: "car.side")
                            .font(.subheadline)
                            .foregroundStyle(Color.emerald)

                        Text("Pilih Mobil Listrik Anda...")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("Atur")
                            .font(.caption.bold())
                            .foregroundStyle(Color.emerald)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            // Bottom Action Bar: Edit Profile Button
            Button(action: onEditTapped) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption.bold())
                    Text("Kelola Profil & Ganti Foto")
                        .font(.caption.bold())
                }
                .foregroundStyle(Color.emerald)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.emerald.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.emerald.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }
}

// MARK: - All Time Metrics Section
private struct AllTimeMetricsSection: View {
    let stats: TimeStats

    var avgKwhPerSession: Double {
        stats.totalSessions > 0 ? (stats.totalKwh / Double(stats.totalSessions)) : 0
    }

    var avgCostPerSession: Double {
        stats.totalSessions > 0 ? (stats.totalCost / Double(stats.totalSessions)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Akumulasi Sepanjang Waktu")
                        .font(.headline)
                    Text("Total pengisian sejak awal menggunakan aplikasi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.subheadline)
                    .foregroundStyle(Color.emerald)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Total Energi",
                    value: Formatters.kwh(stats.totalKwh),
                    subtitle: "Energi terserap",
                    icon: "bolt.fill",
                    tint: Color.emerald
                )

                StatCard(
                    title: "Total Biaya",
                    value: Formatters.currency(stats.totalCost),
                    subtitle: "Pengeluaran listrik",
                    icon: "banknote.fill",
                    tint: .orange
                )

                StatCard(
                    title: "Total Sesi",
                    value: "\(stats.totalSessions) Kali",
                    subtitle: "Kunjungan SPKLU",
                    icon: "repeat",
                    tint: .blue
                )

                StatCard(
                    title: "Rata-rata / Sesi",
                    value: String(format: "%.1f kWh", avgKwhPerSession),
                    subtitle: Formatters.currency(avgCostPerSession),
                    icon: "gauge.with.dots.needle.50percent",
                    tint: .purple
                )
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.caption.bold())
                        .foregroundStyle(tint)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Monthly Trend Chart Card
private struct MonthChartEntry: Identifiable {
    var id: String { label }
    let label: String
    let value: Double
}

private struct MonthlyTrendChartCard: View {
    let monthly: [MonthStats]
    @Binding var selectedMetric: StatsView.ChartMetricType

    private var chartEntries: [MonthChartEntry] {
        monthly.compactMap { item in
            guard let monthStr = item.month else { return nil }
            let val = selectedMetric == .kwh ? item.totalKwh : item.totalCost
            return MonthChartEntry(label: monthStr, value: val)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tren Pengisian Bulanan")
                        .font(.headline)
                    Text("Perkembangan konsumsi energi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Metrik", selection: $selectedMetric) {
                    Text("kWh").tag(StatsView.ChartMetricType.kwh)
                    Text("Rp").tag(StatsView.ChartMetricType.cost)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            // Swift Charts Visualizer
            Chart(chartEntries) { entry in
                BarMark(
                    x: .value("Bulan", entry.label),
                    y: .value(selectedMetric.rawValue, entry.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: selectedMetric == .kwh
                            ? [Color.emerald, Color.emerald.opacity(0.7)]
                            : [Color.orange, Color.orange.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            if selectedMetric == .kwh {
                                Text("\(Int(d))k")
                            } else {
                                Text("\(Int(d / 1000))rb")
                            }
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
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
}

// MARK: - Mode Comparison Section
private struct ModeComparisonSection: View {
    let allTime: TimeStats

    var totalKwh: Double {
        max(1.0, allTime.totalKwh)
    }

    var dcRatio: Double {
        allTime.dc.kwh / totalKwh
    }

    var acRatio: Double {
        allTime.ac.kwh / totalKwh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Perbandingan Mode Pengisian")
                        .font(.headline)
                    Text("Proporsi penggunaan DC Fast Charging vs AC Normal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "powerplug.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.blue)
            }

            // Dual Proportion Bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        // DC segment
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.emerald)
                            .frame(width: max(4, geo.size.width * CGFloat(dcRatio)))

                        // AC segment
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.blue)
                            .frame(width: max(4, geo.size.width * CGFloat(acRatio)))
                    }
                }
                .frame(height: 12)

                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Color.emerald).frame(width: 8, height: 8)
                        Text("DC Fast: \(Int(dcRatio * 100))%")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.emerald)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("AC Normal: \(Int(acRatio * 100))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Two Cards Side-by-Side
            HStack(spacing: 12) {
                ModeDetailCard(
                    title: "DC Fast Charging",
                    icon: "bolt.fill",
                    tint: Color.emerald,
                    sessions: allTime.dc.sessions,
                    kwh: allTime.dc.kwh,
                    cost: allTime.dc.cost
                )

                ModeDetailCard(
                    title: "AC Normal",
                    icon: "powerplug.fill",
                    tint: .blue,
                    sessions: allTime.ac.sessions,
                    kwh: allTime.ac.kwh,
                    cost: allTime.ac.cost
                )
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
}

private struct ModeDetailCard: View {
    let title: String
    let icon: String
    let tint: Color
    let sessions: Int
    let kwh: Double
    let cost: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.kwh(kwh))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(Formatters.currency(cost))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text("\(sessions) sesi tercatat")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Current Month Snapshot Card
private struct CurrentMonthSnapshotCard: View {
    let monthStats: MonthStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bulan Berjalan (\(monthStats.month ?? "Bulan Ini"))")
                        .font(.headline)
                    Text("Aktivitas pengisian daya selama bulan berjalan")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(monthStats.totalSessions) Sesi")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.emerald.opacity(0.12))
                    .foregroundStyle(Color.emerald)
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Energi Terisi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Formatters.kwh(monthStats.totalKwh))
                        .font(.title3.bold())
                        .foregroundStyle(Color.emerald)
                }

                Divider().frame(height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Biaya Pengisian")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Formatters.currency(monthStats.totalCost))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()
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
}

// MARK: - Eco & Fuel Savings Insight Card
private struct EcoSavingsInsightCard: View {
    let totalKwh: Double
    let totalCost: Double

    private var estimatedKmDriven: Double {
        totalKwh * 6.5
    }

    private var equivalentFuelCost: Double {
        estimatedKmDriven * 1400.0
    }

    private var moneySaved: Double {
        max(0, equivalentFuelCost - totalCost)
    }

    private var co2ReducedKg: Double {
        estimatedKmDriven * 0.120
    }

    private var moneySavedString: String {
        Formatters.currency(moneySaved)
    }

    private var co2ReducedString: String {
        String(format: "%.0f kg", co2ReducedKg)
    }

    private var estimatedKmString: String {
        String(format: "%.0f km", estimatedKmDriven)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection
            metricsSection
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

    private var headerSection: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.emerald.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "leaf.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.emerald)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Estimasi Penghematan & Lingkungan")
                    .font(.headline)
                Text("Dibandingkan penggunaan mobil bensin setara")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metricsSection: some View {
        HStack(spacing: 10) {
            EcoInsightItem(
                title: "Hemat Biaya",
                value: moneySavedString,
                subtitle: "vs mobil bensin",
                tint: Color.emerald
            )

            EcoInsightItem(
                title: "CO₂ Dicegah",
                value: co2ReducedString,
                subtitle: "emisi karbon",
                tint: Color.sky
            )

            EcoInsightItem(
                title: "Jarak Tempuh",
                value: estimatedKmString,
                subtitle: "estimasi jarak",
                tint: .purple
            )
        }
    }
}

private struct EcoInsightItem: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - App & Connection Info Section
private struct AppInfoSection: View {
    let onEditProfileTapped: () -> Void
    let onLogoutTapped: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Button(action: onEditProfileTapped) {
                    HStack {
                        Label("Edit Profil Akun", systemImage: "person.crop.circle.badge.pencil")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Divider()

                HStack {
                    Text("Versi Aplikasi")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("1.0.0 (Build 1)")
                        .font(.subheadline.bold())
                }

                Divider()

                HStack {
                    Text("Server Backend")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Config.baseURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button(role: .destructive, action: onLogoutTapped) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Keluar dari Akun")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
