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

    var body: some View {
        NavigationStack {
            Form {
                Section("Lokasi SPKLU") {
                    Picker("Pilih Stasiun *", selection: $selectedStationId) {
                        Text("Pilih SPKLU").tag(nil as Int?)
                        ForEach(availableStations) { st in
                            Text(st.name).tag(st.id as Int?)
                        }
                    }

                    if let connectors = currentStation?.connectors, !connectors.isEmpty {
                        Picker("Konektor / Colokan", selection: $selectedConnectorId) {
                            Text("Pilih Konektor (Opsional)").tag(nil as Int?)
                            ForEach(connectors) { conn in
                                Text("\(conn.currentType) \(conn.plugType) (\(Int(conn.powerKw)) kW)").tag(conn.id as Int?)
                            }
                        }
                        .onChange(of: selectedConnectorId) { _, newId in
                            if let conn = connectors.first(where: { $0.id == newId }) {
                                chargingMode = conn.currentType.uppercased() == "AC" ? "AC" : "DC"
                            }
                        }
                    }

                    Picker("Mode Pengisian *", selection: $chargingMode) {
                        Text("DC Fast Charging").tag("DC")
                        Text("AC Normal").tag("AC")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Waktu Pengisian") {
                    DatePicker("Waktu Mulai", selection: $startedAt)
                    DatePicker("Waktu Selesai", selection: $endedAt)
                }

                Section("Konsumsi Daya & Biaya") {
                    HStack {
                        Text("Energi Terisi (kWh) *")
                        Spacer()
                        TextField("cth: 32.5", text: $kwhText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Total Biaya (Rp)")
                        Spacer()
                        TextField("cth: 82500", text: $costText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Persentase Baterai (SoC)") {
                    HStack {
                        Text("SoC Awal (%)")
                        Spacer()
                        TextField("cth: 60", text: $socStartText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("SoC Akhir (%)")
                        Spacer()
                        TextField("cth: 100", text: $socEndText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    // Smart Calculation Hint
                    if let car = authVM.currentUser?.evModel,
                       let start = Double(socStartText),
                       let end = Double(socEndText),
                       end > start {
                        let delta = end - start
                        let estimatedKwh = car.batteryCapacityKwh * (delta / 100.0)
                        let estimatedCost = estimatedKwh * 2466.0

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text("Estimasi \(car.fullName):")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.emerald)
                            }

                            Text("Kenaikan +\(Int(delta))% membutuhkan sekitar \(String(format: "%.2f", estimatedKwh)) kWh (estimasi biaya Rp \(Int(estimatedCost)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Button {
                                kwhText = String(format: "%.2f", estimatedKwh)
                                costText = "\(Int(estimatedCost))"
                            } label: {
                                Text("Terapkan ke Kolom kWh & Biaya")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.emerald)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Catatan Tambahan") {
                    TextField("Kondisi charger, antrean, dsb.", text: $notesText, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
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
                    Button("Simpan") {
                        saveSession()
                    }
                    .disabled(isSubmitting || selectedStationId == nil || kwhText.isEmpty)
                }
            }
            .task {
                await stationsVM.fetchStations()
                if let first = stationsVM.stations.first {
                    selectedStationId = first.id
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

