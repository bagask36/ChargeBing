import SwiftUI

struct EvCatalogView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = EvModelsViewModel()
    @State private var isSettingActiveCar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Active Selected Car Banner & Calculator
                    if let activeCar = authVM.currentUser?.evModel {
                        ActiveCarCard(car: activeCar)
                            .padding(.horizontal)

                        // Charging Calculator
                        ChargingCalculatorView(car: activeCar)
                            .padding(.horizontal)
                    } else {
                        NoActiveCarCard()
                            .padding(.horizontal)
                    }

                    // Brand Horizontal Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableBrands, id: \.self) { brand in
                                Button {
                                    viewModel.selectedBrand = brand
                                } label: {
                                    Text(brand == "ALL" ? "Semua Pabrikan" : brand)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(viewModel.selectedBrand == brand ? Color.emerald : Color(uiColor: .secondarySystemBackground))
                                        .foregroundStyle(viewModel.selectedBrand == brand ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // EV List
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredModels) { car in
                            EvModelCardView(
                                car: car,
                                isCurrentlySelected: authVM.currentUser?.evModelId == car.id,
                                onSelectAsActive: {
                                    Task {
                                        _ = await authVM.updateActiveCar(evModelId: car.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .searchable(text: $viewModel.searchText, prompt: "Cari merk, model, atau tipe...")
            .navigationTitle("Kendaraan Listrik")
            .refreshable {
                await viewModel.fetchModels()
                await authVM.fetchProfile()
            }
            .task {
                await viewModel.fetchModels()
            }
        }
    }
}

// MARK: - Active Car Card Banner
struct ActiveCarCard: View {
    let car: EvModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MOBIL AKTIF ANDA")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.emerald)

                    Text(car.fullName)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.emerald)
            }

            Divider()
                .overlay(Color.white.opacity(0.15))

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kapasitas Baterai")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text("\(String(format: "%.1f", car.batteryCapacityKwh)) kWh")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Jarak Tempuh (Range)")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text("\(car.rangeKm) km")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Port Pengisian")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text(car.dcPlugType ?? car.acPlugType)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.emerald.opacity(0.15), radius: 10, y: 4)
    }
}

struct NoActiveCarCard: View {
    var body: some View {
        HStack {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Belum Memilih Mobil Listrik")
                    .font(.subheadline.bold())
                Text("Pilih mobil Anda dari daftar di bawah untuk profil pengisian.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - EV Model Card
struct EvModelCardView: View {
    let car: EvModel
    let isCurrentlySelected: Bool
    let onSelectAsActive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(car.brand)
                            .font(.caption.bold())
                            .foregroundStyle(Color.emerald)
                        if let v = car.variant {
                            Text("• \(v)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(car.modelName)
                        .font(.headline)
                }

                Spacer()

                if isCurrentlySelected {
                    Label("Aktif", systemImage: "checkmark.circle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.emerald)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.emerald.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Button(action: onSelectAsActive) {
                        Text("Pilih")
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .secondarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "battery.100.bolt")
                        .foregroundStyle(Color.emerald)
                    Text("\(String(format: "%.1f", car.batteryCapacityKwh)) kWh")
                }
                .font(.caption.bold())

                HStack(spacing: 4) {
                    Image(systemName: "road.lanes")
                        .foregroundStyle(Color.blue)
                    Text("\(car.rangeKm) km")
                }
                .font(.caption.bold())

                HStack(spacing: 4) {
                    Image(systemName: "powerplug")
                        .foregroundStyle(.secondary)
                    Text("AC: \(car.acPlugType)")
                }
                .font(.caption)

                if let dc = car.dcPlugType {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.orange)
                        Text("DC: \(dc)")
                    }
                    .font(.caption)
                }
            }

            if let notes = car.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrentlySelected ? Color.emerald : Color.clear, lineWidth: 1.5)
        )
    }
}

