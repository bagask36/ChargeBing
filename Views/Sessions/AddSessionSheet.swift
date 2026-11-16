import SwiftUI

struct AddSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM

    let onSessionSaved: () -> Void

    @State private var stationsVM = StationsViewModel()
    @State private var sessionsVM = SessionsViewModel()

    @State private var selectedStationId: Int?
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Lokasi SPKLU") {
                    Picker("Pilih Stasiun *", selection: $selectedStationId) {
                        Text("Pilih SPKLU").tag(nil as Int?)
                        ForEach(stationsVM.stations) { st in
                            Text(st.name).tag(st.id as Int?)
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
                        TextField("cth: 20", text: $socStartText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("SoC Akhir (%)")
                        Spacer()
                        TextField("cth: 85", text: $socEndText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
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
                connectorId: nil,
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

