import SwiftUI

struct AddSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM

    var preselectedStation: Station? = nil
    var preselectedConnector: Connector? = nil
    let onSessionSaved: () -> Void

    @State private var stationsVM = StationsViewModel()
    @State private var sessionsVM = SessionsViewModel()

    @State private var selectedStationId: Int?
    @State private var selectedConnectorId: Int?
    @State private var chargingMode: String = "DC"
    @State private var startedAt: Date = Date().addingTimeInterval(-45 * 60)
    @State private var endedAt: Date = Date()
    @State private var kwhText: String = ""
    @State private var costText: String = ""
    @State private var socStartText: String = ""
    @State private var socEndText: String = ""
    @State private var notesText: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(
        preselectedStation: Station? = nil,
        preselectedConnector: Connector? = nil,
        onSessionSaved: @escaping () -> Void = {}
    ) {
        self.preselectedStation = preselectedStation
        self.preselectedConnector = preselectedConnector
        self.onSessionSaved = onSessionSaved
        _selectedStationId = State(initialValue: preselectedStation?.id)
        _selectedConnectorId = State(initialValue: preselectedConnector?.id)
        if let conn = preselectedConnector {
            _chargingMode = State(initialValue: conn.currentType.uppercased() == "AC" ? "AC" : "DC")
        }
    }

    private var availableStations: [Station] {
        if let pre = preselectedStation, !stationsVM.stations.contains(where: { $0.id == pre.id }) {
            return [pre] + stationsVM.stations
        }
        return stationsVM.stations
    }

    private var currentStation: Station? {
        if let pre = preselectedStation, pre.id == selectedStationId {
            return pre
        }
        return stationsVM.stations.first { $0.id == selectedStationId }
    }

    private var isDC: Bool {
        chargingMode == "DC"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Station & Connector Section
                Section {
                    if let st = preselectedStation {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.emerald.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "ev.charger.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.emerald)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(st.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                if let op = st.operatorName {
                                    Text(op)
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.emerald)
                                }

                                if let addr = st.address {
                                    Text(addr)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Stasiun SPKLU *", selection: $selectedStationId) {
                            Text("Pilih Stasiun SPKLU").tag(nil as Int?)
                            ForEach(availableStations) { st in
                                Text("\(st.name)\(st.operatorName != nil ? " (\(st.operatorName!))" : "")")
                                    .tag(st.id as Int?)
                            }
                        }
                    }

                    if let connectors = currentStation?.connectors, !connectors.isEmpty {
                        Picker("Konektor / Colokan", selection: $selectedConnectorId) {
                            Text("Pilih Konektor (Opsional)").tag(nil as Int?)
                            ForEach(connectors) { conn in
                                Text("\(conn.currentType) \(conn.plugType) · \(Int(conn.powerKw)) kW")
                                    .tag(conn.id as Int?)
                            }
                        }
                        .onChange(of: selectedConnectorId) { _, newId in
                            if let conn = connectors.first(where: { $0.id == newId }) {
                                chargingMode = conn.currentType.uppercased() == "AC" ? "AC" : "DC"
                            }
                        }
                    }

                    Picker("Mode Pengisian *", selection: $chargingMode) {
                        Label("DC Fast", systemImage: "bolt.fill").tag("DC")
                        Label("AC Normal", systemImage: "powerplug.fill").tag("AC")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Lokasi & Mode SPKLU", systemImage: "mappin.and.ellipse")
                }

                // MARK: - Time Section
                Section {
                    DatePicker("Waktu Mulai", selection: $startedAt)
                    DatePicker("Waktu Selesai", selection: $endedAt)
                } header: {
                    Label("Waktu Pengisian", systemImage: "clock.fill")
                }

                // MARK: - Energy & Cost Section
                Section {
                    HStack {
                        Label("Energi (kWh) *", systemImage: "bolt.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("cth: 28.5", text: $kwhText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.bold())
                    }

                    HStack {
                        Label("Total Biaya (Rp)", systemImage: "banknote.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("cth: 72000", text: $costText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.bold())
                    }
                } header: {
                    Label("Konsumsi Daya & Biaya", systemImage: "gauge.with.needle.fill")
                } footer: {
                    Text("Tarif rata-rata SPKLU di Indonesia berkisar Rp 2.466 per kWh (DC Fast Charging).")
                        .font(.caption2)
                }

                // MARK: - Battery (SoC) Section
                Section {
                    HStack {
                        Label("SoC Awal (%)", systemImage: "battery.25percent")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("cth: 20", text: $socStartText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.bold())
                    }

                    HStack {
                        Label("SoC Akhir (%)", systemImage: "battery.100percent")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("cth: 80", text: $socEndText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.bold())
                    }

                    // Smart Calculation Hint for Connected EV Model
                    if let car = authVM.currentUser?.evModel,
                       let start = Double(socStartText),
                       let end = Double(socEndText),
                       end > start {
                        let delta = end - start
                        let estimatedKwh = car.batteryCapacityKwh * (delta / 100.0)
                        let estimatedCost = estimatedKwh * 2466.0

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                Text("Estimasi Otomatis (\(car.fullName))")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.emerald)
                            }

                            Text("Kenaikan +\(Int(delta))% membutuhkan sekitar \(String(format: "%.2f", estimatedKwh)) kWh (estimasi biaya Rp \(Int(estimatedCost)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                kwhText = String(format: "%.2f", estimatedKwh)
                                costText = "\(Int(estimatedCost))"
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Terapkan ke Kolom kWh & Biaya")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.emerald)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Label("Status Baterai (SoC)", systemImage: "battery.75percent")
                }

                // MARK: - Notes Section
                Section {
                    TextField("Tulis catatan kondisi stasiun, antrean, atau kecepatan pengisian...", text: $notesText, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Label("Catatan Tambahan (Opsional)", systemImage: "note.text")
                }

                if let err = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Catat Sesi Pengisian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveSession()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(Color.emerald)
                        } else {
                            Text("Simpan")
                                .bold()
                                .foregroundStyle(Color.emerald)
                        }
                    }
                    .disabled(isSubmitting || selectedStationId == nil || kwhText.isEmpty)
                }
            }
            .task {
                if preselectedStation == nil {
                    await stationsVM.fetchStations()
                    if selectedStationId == nil, let first = stationsVM.stations.first {
                        selectedStationId = first.id
                    }
                }
            }
        }
    }

    private func saveSession() {
        guard let stId = selectedStationId, let kwh = Double(kwhText.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Pilih stasiun dan masukkan nilai kWh yang valid."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let isoFormatter = ISO8601DateFormatter()
        let startedIso = isoFormatter.string(from: startedAt)
        let endedIso = isoFormatter.string(from: endedAt)

        let cost = Double(costText)
        let socStart = Int(socStartText)
        let socEnd = Int(socEndText)

        Task {
            let success = await sessionsVM.createSession(
                stationId: stId,
                connectorId: selectedConnectorId,
                evModelId: authVM.currentUser?.evModelId,
                chargingMode: chargingMode,
                startedAt: startedIso,
                endedAt: endedIso,
                kwh: kwh,
                cost: cost,
                socStart: socStart,
                socEnd: socEnd,
                notes: notesText.isEmpty ? nil : notesText
            )

            isSubmitting = false
            if success {
                onSessionSaved()
                dismiss()
            } else {
                errorMessage = sessionsVM.errorMessage ?? "Gagal menyimpan sesi pengisian."
            }
        }
    }
}
