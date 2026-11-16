import SwiftUI

struct StatsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = StatsViewModel()
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header Card
                    if let user = authVM.currentUser {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.emerald.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                Text(user.name.prefix(1).uppercased())
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.emerald)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                showLogoutConfirmation = true
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    if viewModel.isLoading && viewModel.stats == nil {
                        ProgressView("Mengalkulasi statistik...")
                            .padding(.top, 40)
                    } else if let stats = viewModel.stats {
                        // All-time Metrics Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Akumulasi Sepanjang Waktu")
                                .font(.headline)

                            HStack(spacing: 16) {
                                MetricBox(
                                    title: "Total Energi",
                                    value: Formatters.kwh(stats.allTime.totalKwh),
                                    icon: "bolt.fill",
                                    color: .emerald
                                )

                                MetricBox(
                                    title: "Total Pengeluaran",
                                    value: Formatters.currency(stats.allTime.totalCost),
                                    icon: "banknote.fill",
                                    color: .blue
                                )
                            }

                            HStack(spacing: 16) {
                                MetricBox(
                                    title: "Total Sesi",
                                    value: "\(stats.allTime.totalSessions) Kali",
                                    icon: "repeat",
                                    color: .orange
                                )

                                MetricBox(
                                    title: "Rata-rata/Sesi",
                                    value: stats.allTime.totalSessions > 0 ? Formatters.kwh(stats.allTime.totalKwh / Double(stats.allTime.totalSessions)) : "0 kWh",
                                    icon: "gauge.with.dots.needle.50percent",
                                    color: .purple
                                )
                            }
                        }
                        .padding(.horizontal)

                        // Mode Comparison: AC vs DC
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Perbandingan Mode Pengisian")
                                .font(.headline)

                            VStack(spacing: 10) {
                                ModeComparisonRow(
                                    modeName: "DC Fast Charging",
                                    icon: "bolt.fill",
                                    color: .emerald,
                                    sessions: stats.allTime.dc.sessions,
                                    kwh: stats.allTime.dc.kwh,
                                    cost: stats.allTime.dc.cost,
                                    totalKwh: stats.allTime.totalKwh
                                )

                                Divider()

                                ModeComparisonRow(
                                    modeName: "AC Normal Charging",
                                    icon: "powerplug.fill",
                                    color: .blue,
                                    sessions: stats.allTime.ac.sessions,
                                    kwh: stats.allTime.ac.kwh,
                                    cost: stats.allTime.ac.cost,
                                    totalKwh: stats.allTime.totalKwh
                                )
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)

                        // Current Month Summary
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bulan Berjalan (\(stats.currentMonth.month ?? "Bulan Ini"))")
                                .font(.headline)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Energi Terisi")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(Formatters.kwh(stats.currentMonth.totalKwh))
                                        .font(.title3.bold())
                                        .foregroundStyle(Color.emerald)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Biaya Pengisian")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(Formatters.currency(stats.currentMonth.totalCost))
                                        .font(.title3.bold())
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistik & Akun")
            .refreshable {
                await viewModel.fetchStats()
            }
            .task {
                await viewModel.fetchStats()
            }
            .confirmationDialog("Logout", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Keluar Akun", role: .destructive) {
                    Task { await authVM.logout() }
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Apakah Anda yakin ingin logout dari aplikasi ChargeBing?")
            }
        }
    }
}

// MARK: - Metric Box
struct MetricBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Mode Comparison Row
struct ModeComparisonRow: View {
    let modeName: String
    let icon: String
    let color: Color
    let sessions: Int
    let kwh: Double
    let cost: Double
    let totalKwh: Double

    var percentage: Double {
        totalKwh > 0 ? (kwh / totalKwh) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(modeName)
                        .font(.subheadline.bold())
                }

                Spacer()

                Text("\(Int(percentage * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .systemFill))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percentage), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(sessions) Sesi • \(Formatters.kwh(kwh))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(Formatters.currency(cost))
                    .font(.caption2.bold())
            }
            .padding(.top, 2)
        }
    }
}

