import SwiftUI
import MapKit

struct StationsMapView: View {
    @State private var viewModel = StationsViewModel()
    @State private var locationManager = LocationManager.shared

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )

    @State private var showListSheet = false
    @State private var selectedStationForDetail: Station?

    var body: some View {
        ZStack(alignment: .top) {
            // Interactive Map
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(viewModel.stations) { station in
                    Annotation(station.name, coordinate: station.coordinate) {
                        Button {
                            selectedStationForDetail = station
                        } label: {
                            StationPinMarkerView(station: station)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .top)

            // Top Search & Filter Bar
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Cari SPKLU / Alamat...", text: $viewModel.searchText)
                            .onSubmit {
                                Task { await viewModel.fetchStations(userLocation: locationManager.userLocation) }
                            }

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                                Task { await viewModel.fetchStations(userLocation: locationManager.userLocation) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Material.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

                    // Recenter on GPS Location
                    Button {
                        if let loc = locationManager.userLocation {
                            withAnimation {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: loc.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    )
                                )
                            }
                        } else {
                            locationManager.requestPermission()
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.emerald)
                            .frame(width: 44, height: 44)
                            .background(Material.ultraThickMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    }

                    // Open List Mode
                    Button {
                        showListSheet = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Material.ultraThickMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    }
                }
                .padding(.horizontal)

                // Filter Chips (GB/T Usable, AC, DC)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "GB/T Kompatibel Saja",
                            icon: "bolt.badge.checkmark.fill",
                            isSelected: viewModel.usableOnly
                        ) {
                            viewModel.usableOnly.toggle()
                            Task { await viewModel.fetchStations(userLocation: locationManager.userLocation) }
                        }

                        FilterChip(
                            title: "Semua Arus",
                            isSelected: viewModel.filterCurrentType == "ALL"
                        ) {
                            viewModel.filterCurrentType = "ALL"
                            Task { await viewModel.fetchStations(userLocation: locationManager.userLocation) }
                        }

                        FilterChip(
                            title: "DC Fast Only",
                            icon: "bolt.fill",
                            isSelected: viewModel.filterCurrentType == "DC"
                        ) {
                            viewModel.filterCurrentType = "DC"
                            Task { await viewModel.fetchStations(userLocation: locationManager.userLocation) }
                        }

                        FilterChip(
                            title: "AC Normal",
                            isSelected: viewModel.filterCurrentType == "AC"
                        ) {
                            viewModel.filterCurrentType = "AC"
                            Task { await viewModel.fetchStations(userLocation: locationManager.userLocation) }
                        }
                    }
                    .padding(.horizontal)
                }

                // Loading or Error Badge
                if viewModel.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Memuat data SPKLU...")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Material.ultraThickMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                } else if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption2)
                            .lineLimit(1)
                        Button("Coba Lagi") {
                            Task { await viewModel.fetchStations(userLocation: locationManager.userLocation) }
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(Color.emerald)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Material.ultraThickMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
            }
            .padding(.top, 10)
        }
        .task {
            locationManager.requestPermission()
            await viewModel.fetchStations(userLocation: locationManager.userLocation)
        }
        .onChange(of: locationManager.userLocation) { _, newLoc in
            if let loc = newLoc {
                Task {
                    await viewModel.fetchStations(userLocation: loc)
                }
            }
        }
        .sheet(item: $selectedStationForDetail) { station in
            StationDetailSheet(station: station) {
                Task {
                    await viewModel.toggleFavorite(station: station)
                }
            }
        }
        .sheet(isPresented: $showListSheet) {
            NavigationStack {
                List(viewModel.stations) { st in
                    StationRowView(station: st)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStationForDetail = st
                            showListSheet = false
                        }
                }
                .navigationTitle("Daftar Stasiun SPKLU (\(viewModel.stations.count))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Tutup") { showListSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Station Marker Pin
struct StationPinMarkerView: View {
    let station: Station

    var pinColor: Color {
        switch station.gbtStatus {
        case .native: return Color.emerald
        case .adapterOk: return Color.blue
        case .untested: return Color.orange
        case .incompatible: return Color.red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: 34, height: 34)
                    .shadow(color: pinColor.opacity(0.4), radius: 6, y: 3)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )

                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(pinColor)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.emerald : Color(uiColor: .secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }
}

// MARK: - Station Row
struct StationRowView: View {
    let station: Station

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(station.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Spacer()

                if let distance = station.distanceKm {
                    Text(Formatters.distance(distance))
                        .font(.caption.bold())
                        .foregroundStyle(Color.emerald)
                }
            }

            Text(station.address ?? "Alamat tidak tersedia")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(station.gbtStatus.title)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.emerald.opacity(0.12))
                    .foregroundStyle(Color.emerald)
                    .clipShape(Capsule())

                if let op = station.operatorName {
                    Text(op)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

