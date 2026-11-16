import SwiftUI

struct SessionsListView: View {
    @State private var viewModel = SessionsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    ProgressView("Memuat sesi pengisian...")
                } else if viewModel.sessions.isEmpty {
                    ContentUnavailableView(
                        "Belum Ada Sesi Pengisian",
                        systemImage: "bolt.slash.fill",
                        description: Text("Buka tab Peta SPKLU dan pilih stasiun untuk mencatat sesi pengisian mobil Anda.")
                    )
                } else {
                    List {
                        ForEach(viewModel.sessions) { session in
                            SessionCardView(session: session)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let session = viewModel.sessions[index]
                                Task { await viewModel.deleteSession(id: session.id) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Sesi Pengisian")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Mode", selection: $viewModel.modeFilter) {
                        Text("Semua").tag("ALL")
                        Text("DC Fast").tag("DC")
                        Text("AC Normal").tag("AC")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: viewModel.modeFilter) { _, _ in
                        Task { await viewModel.fetchSessions() }
                    }
                }
            }
            .refreshable {
                await viewModel.fetchSessions()
            }
            .task {
                await viewModel.fetchSessions()
            }
        }
    }
}

// MARK: - Session Card
struct SessionCardView: View {
    let session: ChargingSession

    var isDC: Bool {
        session.chargingMode == "DC"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: isDC ? "bolt.fill" : "powerplug.fill")
                    Text(isDC ? "DC Fast Charging" : "AC Normal")
                }
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isDC ? Color.emerald.opacity(0.15) : Color.blue.opacity(0.15))
                .foregroundStyle(isDC ? Color.emerald : Color.blue)
                .clipShape(Capsule())

                Spacer()

                Text(Formatters.relativeTime(session.startedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.station?.name ?? "Stasiun SPKLU")
                    .font(.headline)

                if let car = session.evModel {
                    Text("🚗 \(car.brand) \(car.modelName)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Energi Terisi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Formatters.kwh(session.kwh))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.emerald)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Biaya")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Formatters.currency(session.cost))
                        .font(.subheadline.bold())
                }

                Spacer()

                if let start = session.socStart, let end = session.socEnd {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Baterai (SoC)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(start)% → \(end)%")
                            .font(.subheadline.bold())
                    }
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

