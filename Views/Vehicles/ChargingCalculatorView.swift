import SwiftUI

struct ChargingCalculatorView: View {
    let car: EvModel
    var onApplyToSession: ((Double, Int, Int, Double) -> Void)? = nil

    @State private var currentSoC: Double = 60.0
    @State private var targetSoC: Double = 100.0
    @State private var electricityRate: Double = 2466.0 // Tarif PLN SPKLU per kWh

    // Perhitungan energi yang dibutuhkan
    var deltaPercentage: Double {
        max(0, targetSoC - currentSoC)
    }

    var kwhNeeded: Double {
        car.batteryCapacityKwh * (deltaPercentage / 100.0)
    }

    var addedRangeKm: Double {
        Double(car.rangeKm) * (deltaPercentage / 100.0)
    }

    var estimatedCost: Double {
        kwhNeeded * electricityRate
    }

    // Estimasi durasi (dengan asumsi efisiensi charging 92%)
    func estimatedDuration(powerKw: Double) -> String {
        guard powerKw > 0 else { return "-" }
        let effectiveKwh = kwhNeeded / 0.92
        let hours = effectiveKwh / powerKw
        let totalMinutes = Int(hours * 60)

        if totalMinutes < 60 {
            return "\(totalMinutes) menit"
        } else {
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            return m > 0 ? "\(h) jam \(m) mnt" : "\(h) jam"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .foregroundStyle(Color.emerald)
                        Text("KALKULATOR ESTIMASI CHARGING")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.emerald)
                    }

                    Text("Estimasi Daya & Kebutuhan kWh")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text("\(String(format: "%.1f", car.batteryCapacityKwh)) kWh")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.emerald.opacity(0.12))
                    .foregroundStyle(Color.emerald)
                    .clipShape(Capsule())
            }

            // Visual Battery Gauge
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background Bar
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(uiColor: .systemFill))
                            .frame(height: 22)

                        // Delta / To Charge Bar (Yellow/Sky)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.sky)
                            .frame(width: max(0, geo.size.width * CGFloat(targetSoC / 100.0)), height: 22)

                        // Current Battery Bar (Green)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.emerald)
                            .frame(width: max(0, geo.size.width * CGFloat(currentSoC / 100.0)), height: 22)
                    }
                }
                .frame(height: 22)

                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Color.emerald).frame(width: 8, height: 8)
                        Text("Saat Ini: \(Int(currentSoC))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.sky).frame(width: 8, height: 8)
                        Text("Akan Diisi: +\(Int(deltaPercentage))%")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.sky)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.primary).frame(width: 8, height: 8)
                        Text("Target: \(Int(targetSoC))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Slider Controls
            VStack(spacing: 14) {
                // Current Battery Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Persentase Baterai Saat Ini")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(currentSoC))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.emerald)
                    }

                    Slider(value: $currentSoC, in: 0...95, step: 5) {
                        Text("Baterai Saat Ini")
                    }
                    .tint(Color.emerald)
                    .onChange(of: currentSoC) { _, newVal in
                        if targetSoC <= newVal {
                            targetSoC = min(100, newVal + 5)
                        }
                    }

                    // Quick Select Buttons
                    HStack(spacing: 6) {
                        ForEach([10, 20, 40, 50, 60, 80], id: \.self) { val in
                            Button {
                                currentSoC = Double(val)
                                if targetSoC <= currentSoC {
                                    targetSoC = min(100, currentSoC + 5)
                                }
                            } label: {
                                Text("\(val)%")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(currentSoC == Double(val) ? Color.emerald : Color(uiColor: .systemFill))
                                    .foregroundStyle(currentSoC == Double(val) ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Divider()

                // Target Battery Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Target Pengisian yang Diinginkan")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(targetSoC))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.sky)
                    }

                    Slider(value: $targetSoC, in: min(currentSoC + 1, 100)...100, step: 5) {
                        Text("Target Pengisian")
                    }
                    .tint(Color.sky)

                    // Quick Presets
                    HStack(spacing: 8) {
                        Button {
                            targetSoC = 80
                        } label: {
                            Text("80% (Rekomendasi Harian)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(targetSoC == 80 ? Color.sky : Color(uiColor: .systemFill))
                                .foregroundStyle(targetSoC == 80 ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .disabled(currentSoC >= 80)

                        Button {
                            targetSoC = 100
                        } label: {
                            Text("100% (Penuh / Luar Kota)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(targetSoC == 100 ? Color.sky : Color(uiColor: .systemFill))
                                .foregroundStyle(targetSoC == 100 ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Main Results Grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Result: kWh Needed
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Energi yang Dibutuhkan")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.2f kWh", kwhNeeded))
                            .font(.title2.bold())
                            .foregroundStyle(Color.emerald)

                        Text("+\(Int(deltaPercentage))% dari \(String(format: "%.1f", car.batteryCapacityKwh)) kWh")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.emerald.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.emerald.opacity(0.2), lineWidth: 1)
                    )

                    // Result: Added Range (km)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tambahan Jarak Tempuh")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(String(format: "+%.0f km", addedRangeKm))
                            .font(.title2.bold())
                            .foregroundStyle(Color.sky)

                        Text("Total Range: \(car.rangeKm) km")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sky.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.sky.opacity(0.2), lineWidth: 1)
                    )
                }

                // Estimated Cost & Duration
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimasi Biaya Pengisian")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Formatters.currency(estimatedCost))
                                .font(.title3.bold())
                        }

                        Spacer()

                        Text("Tarif: Rp 2.466/kWh")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .systemFill))
                            .clipShape(Capsule())
                    }

                    Divider()

                    // Time Estimation for AC vs DC
                    HStack(spacing: 20) {
                        if let maxDc = car.maxDcKw, car.hasDc {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("⚡ DC Fast (\(Int(min(maxDc, 50))) kW)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.emerald)
                                Text(estimatedDuration(powerKw: min(maxDc, 50)))
                                    .font(.subheadline.bold())
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            let acPower = car.maxAcKw ?? 3.3
                            Text("🔌 AC Normal (\(String(format: "%.1f", acPower)) kW)")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.sky)
                            Text(estimatedDuration(powerKw: acPower))
                                .font(.subheadline.bold())
                        }

                        Spacer()
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Optional Apply to Session Form Action
            if let onApply = onApplyToSession {
                Button {
                    onApply(kwhNeeded, Int(currentSoC), Int(targetSoC), estimatedCost)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Gunakan Estimasi Ini di Sesi Pengisian")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.emerald)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// Color Sky helper
extension Color {
    static let sky = Color(red: 14/255, green: 165/255, blue: 233/255)
}

