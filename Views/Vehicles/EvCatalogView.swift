import SwiftUI

struct EvCatalogView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = EvModelsViewModel()
    @State private var isSettingActiveCar = false
    @State private var showCalculator = false
    @State private var selectedCarForDetail: EvModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Active EV Hero Showcase
                    if let activeCar = authVM.currentUser?.evModel {
                        ActiveCarHeroCard(
                            car: activeCar,
                            isCalculatorOpen: $showCalculator
                        )
                        .padding(.horizontal)

                        // Collapsible / Interactive Charging Calculator
                        if showCalculator {
                            ChargingCalculatorView(car: activeCar)
                                .padding(.horizontal)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity
                                ))
                        }
                    } else {
                        NoActiveCarCard()
                            .padding(.horizontal)
                    }

                    // MARK: - Brand Horizontal Filter Bar
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Katalog Mobil Listrik Indonesia")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("\(viewModel.filteredModels.count) Model")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.availableBrands, id: \.self) { brand in
                                    let isSelected = viewModel.selectedBrand == brand
                                    let count = brand == "ALL" ? viewModel.models.count : viewModel.models.filter { $0.brand == brand }.count

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.selectedBrand = brand
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(brand == "ALL" ? "Semua Merk" : brand)
                                                .font(.subheadline.bold())

                                            Text("\(count)")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color.emerald : Color(uiColor: .secondarySystemGroupedBackground))
                                        )
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                        .shadow(color: isSelected ? Color.emerald.opacity(0.25) : Color.clear, radius: 6, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - EV Models List
                    if viewModel.isLoading && viewModel.models.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color.emerald)
                            Text("Memuat data mobil listrik...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if viewModel.filteredModels.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Mobil Tidak Ditemukan")
                                .font(.headline)
                            Text("Coba cari kata kunci merk atau tipe mobil yang berbeda.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredModels) { car in
                                let isSelected = authVM.currentUser?.evModelId == car.id

                                EvModelCardView(
                                    car: car,
                                    isCurrentlySelected: isSelected,
                                    onSelectAsActive: {
                                        Task {
                                            _ = await authVM.updateActiveCar(evModelId: car.id)
                                        }
                                    },
                                    onTapDetail: {
                                        selectedCarForDetail = car
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .searchable(text: $viewModel.searchText, prompt: "Cari Wuling, BYD, Hyundai, Ioniq...")
            .navigationTitle("Mobil Listrik")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.fetchModels()
                await authVM.fetchProfile()
            }
            .task {
                await viewModel.fetchModels()
                if authVM.currentUser == nil || authVM.currentUser?.evModel == nil {
                    await authVM.fetchProfile()
                }
            }
            .sheet(item: $selectedCarForDetail) { car in
                EvModelDetailSheet(
                    car: car,
                    isCurrentlySelected: authVM.currentUser?.evModelId == car.id,
                    onSelectAsActive: {
                        selectedCarForDetail = nil
                        Task {
                            _ = await authVM.updateActiveCar(evModelId: car.id)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Active Car Hero Card
private struct ActiveCarHeroCard: View {
    let car: EvModel
    @Binding var isCalculatorOpen: Bool

    var isGBT: Bool {
        (car.dcPlugType?.uppercased().contains("GB/T") ?? false) || car.acPlugType.uppercased().contains("GB/T")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Badge & Action
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.emerald)
                        .frame(width: 8, height: 8)

                    Text("MOBIL AKTIF ANDA")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.emerald)
                        .tracking(0.5)

                    if isGBT {
                        Text("GB/T NATIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.emerald)
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCalculatorOpen.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCalculatorOpen ? "chevron.up" : "bolt.badge.clock.fill")
                        Text(isCalculatorOpen ? "Tutup" : "Kalkulator")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.emerald)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.emerald.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // Car Brand & Model Title
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(car.brand)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.emerald)

                    if let v = car.variant {
                        Text("• \(v)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(car.modelName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Divider()
                .overlay(Color.primary.opacity(0.08))

            // Specs Row
            HStack(spacing: 12) {
                CarHeroSpecItem(
                    title: "Baterai",
                    value: "\(String(format: "%.1f", car.batteryCapacityKwh)) kWh",
                    icon: "battery.100percent",
                    tint: Color.emerald
                )

                Divider().frame(height: 32)

                CarHeroSpecItem(
                    title: "Range",
                    value: "\(car.rangeKm) km",
                    icon: "road.lanes",
                    tint: Color.sky
                )

                Divider().frame(height: 32)

                CarHeroSpecItem(
                    title: "Port DC",
                    value: car.dcPlugType ?? "-",
                    icon: "bolt.fill",
                    tint: .orange
                )

                Divider().frame(height: 32)

                CarHeroSpecItem(
                    title: "Port AC",
                    value: car.acPlugType,
                    icon: "powerplug.fill",
                    tint: .blue
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.emerald.opacity(0.2), lineWidth: 1.5)
        )
    }
}

private struct CarHeroSpecItem: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - No Active Car Card
private struct NoActiveCarCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Belum Memilih Mobil Aktif")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("Pilih mobil Anda dari katalog di bawah untuk menyesuaikan estimasi pengisian daya dan kecocokan colokan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - EV Model Card View
struct EvModelCardView: View {
    let car: EvModel
    let isCurrentlySelected: Bool
    let onSelectAsActive: () -> Void
    let onTapDetail: () -> Void

    var isGBT: Bool {
        (car.dcPlugType?.uppercased().contains("GB/T") ?? false) || car.acPlugType.uppercased().contains("GB/T")
    }

    var body: some View {
        Button(action: onTapDetail) {
            VStack(alignment: .leading, spacing: 12) {
                // Top Row: Brand, Model & Select Button
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(car.brand)
                                .font(.caption.bold())
                                .foregroundStyle(Color.emerald)

                            if let v = car.variant {
                                Text("• \(v)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if isGBT {
                                Text("GB/T")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(Color.emerald)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.emerald.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(car.modelName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    if isCurrentlySelected {
                        Label("Aktif", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color.emerald)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.emerald.opacity(0.14))
                            .clipShape(Capsule())
                    } else {
                        Button(action: onSelectAsActive) {
                            Text("Pilih")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .systemFill))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Specs Badges Row
                HStack(spacing: 8) {
                    // Battery
                    HStack(spacing: 4) {
                        Image(systemName: "battery.100.bolt")
                            .font(.caption2)
                            .foregroundStyle(Color.emerald)
                        Text("\(String(format: "%.1f", car.batteryCapacityKwh)) kWh")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Range
                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .font(.caption2)
                            .foregroundStyle(Color.sky)
                        Text("\(car.rangeKm) km")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // DC Plug
                    if let dc = car.dcPlugType {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("DC: \(dc)")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }

                // Optional Notes
                if let notes = car.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCurrentlySelected ? Color.emerald.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: isCurrentlySelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EV Model Detail Sheet
private struct EvModelDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let car: EvModel
    let isCurrentlySelected: Bool
    let onSelectAsActive: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.emerald.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.emerald)
                        }

                        VStack(spacing: 4) {
                            Text(car.brand)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.emerald)

                            Text(car.modelName)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)

                            if let v = car.variant {
                                Text(v)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if isCurrentlySelected {
                            Label("Mobil Aktif Saat Ini", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Color.emerald)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.emerald.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Specifications Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Spesifikasi Kendaraan")
                            .font(.headline)

                        VStack(spacing: 12) {
                            CarDetailSpecRow(
                                title: "Kapasitas Baterai",
                                value: "\(String(format: "%.1f", car.batteryCapacityKwh)) kWh",
                                icon: "battery.100percent",
                                tint: Color.emerald
                            )

                            CarDetailSpecRow(
                                title: "Estimasi Jarak Tempuh",
                                value: "\(car.rangeKm) km (NEDC / CLTC)",
                                icon: "road.lanes",
                                tint: Color.sky
                            )

                            CarDetailSpecRow(
                                title: "Port Pengisian AC",
                                value: car.acPlugType,
                                icon: "powerplug.fill",
                                tint: .blue
                            )

                            if let maxAc = car.maxAcKw {
                                CarDetailSpecRow(
                                    title: "Daya Maksimal AC",
                                    value: "\(String(format: "%.1f", maxAc)) kW",
                                    icon: "speedometer",
                                    tint: .blue
                                )
                            }

                            CarDetailSpecRow(
                                title: "Mendukung DC Fast",
                                value: car.hasDc ? "Ya (\(car.dcPlugType ?? "-"))" : "Tidak",
                                icon: "bolt.fill",
                                tint: car.hasDc ? .orange : .secondary
                            )

                            if let maxDc = car.maxDcKw {
                                CarDetailSpecRow(
                                    title: "Daya Maksimal DC",
                                    value: "\(Int(maxDc)) kW",
                                    icon: "bolt.badge.clock.fill",
                                    tint: .orange
                                )
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Notes (if any)
                    if let notes = car.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Catatan & Adaptor")
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

                    // Action Button
                    if !isCurrentlySelected {
                        Button(action: onSelectAsActive) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Jadikan Sebagai Mobil Aktif")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.emerald)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.emerald.opacity(0.35), radius: 8, y: 4)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Detail Kendaraan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { dismiss() }
                        .font(.subheadline.bold())
                }
            }
        }
    }
}

private struct CarDetailSpecRow: View {
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
        }
        .padding(.vertical, 2)
    }
}
