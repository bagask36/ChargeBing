import SwiftUI

struct AddSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM

    var sessionToEdit: ChargingSession? = nil
    var preselectedStation: Station? = nil
    var preselectedConnector: Connector? = nil
    let onSessionSaved: () -> Void
    var onSessionUpdated: ((ChargingSession) -> Void)? = nil

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
    @State private var odometerText: String = ""
    @State private var distanceText: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var isEditing: Bool {
        sessionToEdit != nil
    }

    init(
        sessionToEdit: ChargingSession? = nil,
        preselectedStation: Station? = nil,
        preselectedConnector: Connector? = nil,
        onSessionSaved: @escaping () -> Void = {},
        onSessionUpdated: ((ChargingSession) -> Void)? = nil
    ) {
        self.sessionToEdit = sessionToEdit
        let initialStation = preselectedStation ?? sessionToEdit?.station
        let initialConnector = preselectedConnector ?? sessionToEdit?.connector
        self.preselectedStation = initialStation
        self.preselectedConnector = initialConnector
        self.onSessionSaved = onSessionSaved
        self.onSessionUpdated = onSessionUpdated

        _selectedStationId = State(initialValue: initialStation?.id ?? sessionToEdit?.stationId)
        _selectedConnectorId = State(initialValue: initialConnector?.id ?? sessionToEdit?.connectorId)

        if let mode = sessionToEdit?.chargingMode {
            _chargingMode = State(initialValue: mode)
        } else if let conn = initialConnector {
            _chargingMode = State(initialValue: conn.currentType.uppercased() == "AC" ? "AC" : "DC")
        } else {
            _chargingMode = State(initialValue: "DC")
        }

        if let session = sessionToEdit {
            if let startDate = Formatters.parseDate(session.startedAt) {
                _startedAt = State(initialValue: startDate)
            }
            if let ended = session.endedAt, let endDate = Formatters.parseDate(ended) {
                _endedAt = State(initialValue: endDate)
            }
            let kwhStr = session.kwh.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(session.kwh))" : String(format: "%.2f", session.kwh)
            _kwhText = State(initialValue: kwhStr)
            _costText = State(initialValue: session.cost != nil ? "\(Int(session.cost!))" : "")
            _socStartText = State(initialValue: session.socStart != nil ? "\(session.socStart!)" : "")
            _socEndText = State(initialValue: session.socEnd != nil ? "\(session.socEnd!)" : "")
            _notesText = State(initialValue: session.notes ?? "")
            _odometerText = State(initialValue: session.odometerKm.map { "\($0)" } ?? "")
            _distanceText = State(initialValue: session.distanceKmInput.map { Self.formatNumber($0) } ?? "")
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private static func parseDouble(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    /// Sesi charging terakhir sebelum waktu mulai sesi ini
    private var previousSession: ChargingSession? {
        sessionsVM.sessions
            .filter { $0.id != sessionToEdit?.id }
            .compactMap { s -> (ChargingSession, Date)? in
                guard let d = Formatters.parseDate(s.startedAt), d < startedAt else { return nil }
                return (s, d)
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    /// Jarak dihitung otomatis dari selisih odometer jika input manual kosong
    private var autoDistanceKm: Double? {
        guard let odo = Int(odometerText), let prevOdo = previousSession?.odometerKm, odo >= prevOdo else { return nil }
        return Double(odo - prevOdo)
    }

    private var effectiveDistanceKm: Double? {
        Self.parseDouble(distanceText) ?? autoDistanceKm
    }

    private var efficiencyKmPerKwh: Double? {
        guard let dist = effectiveDistanceKm, let prev = previousSession, prev.kwh > 0 else { return nil }
        return dist / prev.kwh
    }

    private var availableStations: [Station] {
        var list = stationsVM.stations
        if let pre = preselectedStation ?? sessionToEdit?.station, !list.contains(where: { $0.id == pre.id }) {
            list.insert(pre, at: 0)
        }
        return list
    }

    private var currentStation: Station? {
        if let pre = preselectedStation, pre.id == selectedStationId {
            return pre
        }
        if let st = sessionToEdit?.station, st.id == selectedStationId {
            return st
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

                // MARK: - Jarak Tempuh & Efisiensi Section
                Section {
                    HStack {
                        Label("Odometer (km)", systemImage: "gauge.open.with.lines.needle.33percent")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("cth: 12450", text: $odometerText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.bold())
                    }

                    HStack {
                        Label("Jarak Tempuh (km)", systemImage: "road.lanes")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(autoDistanceKm.map { "Otomatis: \(Self.formatNumber($0))" } ?? "cth: 230", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.bold())
                    }

                    if let prev = previousSession {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text("Charging terakhir: \(Formatters.dateTime(prev.startedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                EfficiencyPill(title: "Energi Terakhir", value: Formatters.kwh(prev.kwh), tint: .blue)
                                if let odo = prev.odometerKm {
                                    EfficiencyPill(title: "Odometer Terakhir", value: "\(odo) km", tint: .orange)
                                }
                            }

                            if let eff = efficiencyKmPerKwh, let dist = effectiveDistanceKm {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Image(systemName: "leaf.fill")
                                        .foregroundStyle(Color.emerald)
                                    Text(String(format: "%.2f km/kWh", eff))
                                        .font(.title3.bold())
                                        .foregroundStyle(Color.emerald)
                                    Spacer()
                                    Text(String(format: "%.1f kWh/100km", 100 / eff))
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Self.formatNumber(dist)) km ÷ \(String(format: "%.2f", prev.kwh)) kWh (energi charging terakhir)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Isi odometer atau jarak tempuh untuk menghitung efisiensi km/kWh.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Jarak Tempuh & Efisiensi", systemImage: "road.lanes")
                } footer: {
                    Text(previousSession == nil
                         ? "Belum ada sesi charging sebelumnya. Isi odometer agar sesi berikutnya bisa dihitung otomatis."
                         : "Jarak dihitung otomatis dari selisih odometer jika kolom jarak dikosongkan. Efisiensi = jarak ÷ kWh charging terakhir.")
                        .font(.caption2)
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
            .navigationTitle(isEditing ? "Edit Sesi Pengisian" : "Catat Sesi Pengisian")
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
                            Text(isEditing ? "Perbarui" : "Simpan")
                                .bold()
                                .foregroundStyle(Color.emerald)
                        }
                    }
                    .disabled(isSubmitting || selectedStationId == nil || kwhText.isEmpty)
                }
            }
            .task {
                await sessionsVM.fetchSessions()
                if preselectedStation == nil && sessionToEdit?.station == nil {
                    await stationsVM.fetchStations()
                    if selectedStationId == nil, let first = stationsVM.stations.first {
                        selectedStationId = first.id
                    }
                } else if stationsVM.stations.isEmpty {
                    await stationsVM.fetchStations()
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
            if let session = sessionToEdit {
                let updated = await sessionsVM.updateSession(
                    id: session.id,
                    stationId: stId,
                    connectorId: selectedConnectorId,
                    evModelId: session.evModelId ?? authVM.currentUser?.evModelId,
                    chargingMode: chargingMode,
                    startedAt: startedIso,
                    endedAt: endedIso,
                    kwh: kwh,
                    cost: cost,
                    socStart: socStart,
                    socEnd: socEnd,
                    odometerKm: Int(odometerText),
                    distanceKm: Self.parseDouble(distanceText),
                    notes: notesText.isEmpty ? nil : notesText
                )

                isSubmitting = false
                if let updated = updated {
                    onSessionUpdated?(updated)
                    onSessionSaved()
                    dismiss()
                } else {
                    errorMessage = sessionsVM.errorMessage ?? "Gagal memperbarui sesi pengisian."
                }
            } else {
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
                    odometerKm: Int(odometerText),
                    distanceKm: Self.parseDouble(distanceText),
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
}

// MARK: - Edit Session Sheet Helper
struct EditSessionSheet: View {
    let session: ChargingSession
    var onSessionUpdated: ((ChargingSession) -> Void)? = nil

    var body: some View {
        AddSessionSheet(
            sessionToEdit: session,
            preselectedStation: session.station,
            preselectedConnector: session.connector,
            onSessionSaved: {},
            onSessionUpdated: onSessionUpdated
        )
    }
}

// MARK: - Efficiency Pill
struct EfficiencyPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
