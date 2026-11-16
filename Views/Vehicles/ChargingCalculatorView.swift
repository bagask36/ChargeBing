import SwiftUI

struct ChargingCalculatorView: View {
    let car: EvModel
    var onApplyToSession: ((Double, Int, Int, Double) -> Void)? = nil

    @State private var currentSoC: Double = 20.0
    @State private var targetSoC: Double = 80.0
    @State private var electricityRate: Double = 2466.0 // Tarif PLN SPKLU per kWh
    @State private var showCustomRate: Bool = false

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

    // Estimasi durasi (asumsi efisiensi charging 92%)
    func estimatedDuration(powerKw: Double) -> String {
        guard powerKw > 0 else { return "-" }
        let effectiveKwh = kwhNeeded / 0.92
        let hours = effectiveKwh / powerKw
        let totalMinutes = Int(hours * 60)

        if totalMinutes < 1 {
            return "< 1 menit"
        } else if totalMinutes < 60 {
            return "\(totalMinutes) menit"
        } else {
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            return m > 0 ? "\(h)j \(m)m" : "\(h) jam"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.emerald.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.emerald)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Kalkulator Pengisian Daya")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Simulasi kWh, jarak tempuh, & biaya")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(String(format: "%.1f", car.batteryCapacityKwh)) kWh")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.emerald.opacity(0.12))
                    .foregroundStyle(Color.emerald)
                    .clipShape(Capsule())
            }

            // MARK: - Visual Battery Indicator
            VStack(spacing: 10) {
                GeometryReader { geo in
                    let totalWidth = geo.size.width - 10 // Reserve space for battery terminal
                    let startRatio = CGFloat(min(100, max(0, currentSoC))) / 100.0
                    let targetRatio = CGFloat(min(100, max(0, targetSoC))) / 100.0
                    let currentWidth = totalWidth * startRatio
                    let addedWidth = max(0, totalWidth * (targetRatio - startRatio))

                    HStack(spacing: 4) {
                        // Battery Body Shell
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.08))

                            // Current SoC (Emerald)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.emerald, Color.emerald.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, currentWidth))

                            // Added SoC (Sky Blue)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.sky.opacity(0.9), Color.sky.opacity(0.65)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: addedWidth)
                                .offset(x: currentWidth)
                        }
                        .frame(height: 26)

                        // Battery Terminal Tip (+)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 5, height: 12)
                    }
                }
                .frame(height: 26)

                // Battery Legend & Metrics
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Color.emerald).frame(width: 7, height: 7)
                        Text("Awal: \(Int(currentSoC))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.sky).frame(width: 7, height: 7)
                        Text("Diisi: +\(Int(deltaPercentage))%")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.sky)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.primary.opacity(0.6)).frame(width: 7, height: 7)
                        Text("Target: \(Int(targetSoC))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // MARK: - Sliders & Presets
            VStack(spacing: 14) {
                // Current SoC Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Persentase Baterai Saat Ini")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(currentSoC))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.emerald)
                    }

                    Slider(value: $currentSoC, in: 0...99, step: 1)
                        .tint(Color.emerald)
                        .onChange(of: currentSoC) { _, newVal in
                            if newVal >= targetSoC {
                                targetSoC = min(100, newVal + 1)
                            }
                        }

                    // Quick Start Presets
                    HStack(spacing: 6) {
                        Text("Preset:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        ForEach([10.0, 20.0, 40.0, 60.0], id: \.self) { val in
                            Button {
                                currentSoC = val
                                if targetSoC <= val { targetSoC = min(100, val + 40) }
                            } label: {
                                Text("\(Int(val))%")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(currentSoC == val ? Color.emerald : Color.primary.opacity(0.06))
                                    .foregroundStyle(currentSoC == val ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // Target SoC Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Target Pengisian Baterai")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(targetSoC))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.sky)
                    }

                    Slider(value: $targetSoC, in: 1...100, step: 1)
                        .tint(Color.sky)
                        .onChange(of: targetSoC) { _, newVal in
                            if newVal <= currentSoC {
                                currentSoC = max(0, newVal - 1)
                            }
                        }

                    // Quick Target Presets
                    HStack(spacing: 6) {
                        Text("Preset:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        ForEach([80.0, 90.0, 100.0], id: \.self) { val in
                            Button {
                                targetSoC = val
                                if currentSoC >= val { currentSoC = max(0, val - 40) }
                            } label: {
                                HStack(spacing: 3) {
                                    Text("\(Int(val))%")
                                    if val == 80.0 {
                                        Text("(Optimal)")
                                            .font(.system(size: 9))
                                    }
                                }
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(targetSoC == val ? Color.sky : Color.primary.opacity(0.06))
                                .foregroundStyle(targetSoC == val ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // MARK: - Simulation Result Cards (3 Grid Items)
            HStack(spacing: 10) {
                // Energi Diperlukan
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.emerald)
                        Text("Energi")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: "%.1f", kwhNeeded))
                        .font(.title3.bold())
                        .foregroundStyle(Color.emerald)
                    Text("kWh")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.emerald.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.emerald.opacity(0.2), lineWidth: 1)
                )

                // Tambahan Jarak Tempuh
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .font(.caption2)
                            .foregroundStyle(Color.sky)
                        Text("Jarak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: "+%.0f", addedRangeKm))
                        .font(.title3.bold())
                        .foregroundStyle(Color.sky)
                    Text("km range")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sky.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.sky.opacity(0.2), lineWidth: 1)
                )

                // Estimasi Biaya
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "banknote.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("Biaya")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(Formatters.currency(estimatedCost))
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("@Rp \(Int(electricityRate))/kWh")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            }

            // MARK: - Charging Time Estimations (AC vs DC)
            VStack(alignment: .leading, spacing: 10) {
                Text("Estimasi Waktu Pengisian")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    // DC Fast Charging
                    if let maxDc = car.maxDcKw, car.hasDc {
                        let effectiveDcKw = min(maxDc, 60.0) // Asumsi SPKLU DC 60kW umum
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.emerald.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "bolt.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.emerald)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("DC Fast (\(Int(effectiveDcKw)) kW)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.emerald)
                                Text(estimatedDuration(powerKw: effectiveDcKw))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(uiColor: .systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // AC Normal Charging
                    let acPower = car.maxAcKw ?? 3.3
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "powerplug.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AC Normal (\(String(format: "%.1f", acPower)) kW)")
                                .font(.caption2.bold())
                                .foregroundStyle(.blue)
                            Text(estimatedDuration(powerKw: acPower))
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Optional Apply to Session Form Action
            if let onApply = onApplyToSession {
                Button {
                    onApply(kwhNeeded, Int(currentSoC), Int(targetSoC), estimatedCost)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Terapkan ke Catatan Sesi Pengisian")
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
