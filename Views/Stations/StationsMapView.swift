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
                    Annotation("", coordinate: station.coordinate) {
                        Button {
                            selectedStationForDetail = station
                        } label: {
                            StationPinMarkerView(
                                station: station,
                                isSelected: selectedStationForDetail?.id == station.id
                            )
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

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
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

                    // Refresh Button (Muat Data Ulang)
                    Button {
                        Task {
                            await viewModel.fetchStations(userLocation: locationManager.userLocation, forceRefresh: true)
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color.emerald)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.emerald)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(Material.ultraThickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    }
                    .disabled(viewModel.isLoading)

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
                        }

                        FilterChip(
                            title: "Semua Arus",
                            isSelected: viewModel.filterCurrentType == "ALL"
                        ) {
                            viewModel.filterCurrentType = "ALL"
                        }

                        FilterChip(
                            title: "DC Fast Only",
                            icon: "bolt.fill",
                            isSelected: viewModel.filterCurrentType == "DC"
                        ) {
                            viewModel.filterCurrentType = "DC"
                        }

                        FilterChip(
                            title: "AC Normal",
                            isSelected: viewModel.filterCurrentType == "AC"
                        ) {
                            viewModel.filterCurrentType = "AC"
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
                            Task { await viewModel.fetchStations(userLocation: locationManager.userLocation, forceRefresh: true) }
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
            if viewModel.allStations.isEmpty {
                await viewModel.fetchStations(userLocation: locationManager.userLocation)
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
                .refreshable {
                    await viewModel.fetchStations(userLocation: locationManager.userLocation, forceRefresh: true)
                }
                .navigationTitle("Daftar Stasiun SPKLU (\(viewModel.stations.count))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task {
                                await viewModel.fetchStations(userLocation: locationManager.userLocation, forceRefresh: true)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.emerald)
                        }
                        .disabled(viewModel.isLoading)
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button("Tutup") { showListSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Modern Teardrop Marker Pin Shape
struct MarkerPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = w / 2
        let bulbCenter = CGPoint(x: w / 2, y: r)
        let tip = CGPoint(x: w / 2, y: h)

        path.move(to: tip)
        path.addQuadCurve(
            to: CGPoint(x: 0, y: r),
            control: CGPoint(x: 0, y: h * 0.72)
        )
        path.addArc(
            center: bulbCenter,
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: w, y: h * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Station Marker Pin
struct StationPinMarkerView: View {
    let station: Station
    var isSelected: Bool = false

    var gradientColors: [Color] {
        switch station.gbtStatus {
        case .native:
            return [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)]
        case .adapterOk:
            return [Color(red: 59/255, green: 130/255, blue: 246/255), Color(red: 29/255, green: 78/255, blue: 216/255)]
        case .untested:
            return [Color(red: 245/255, green: 158/255, blue: 11/255), Color(red: 217/255, green: 119/255, blue: 6/255)]
        case .incompatible:
            return [Color(red: 239/255, green: 68/255, blue: 68/255), Color(red: 185/255, green: 28/255, blue: 28/255)]
        }
    }

    var primaryColor: Color {
        gradientColors.first ?? Color.emerald
    }

    var maxKwText: String? {
        if let maxKw = station.connectors?.map(\.powerKw).max(), maxKw > 0 {
            return "\(Int(maxKw))kW"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 2) {
            // Main Teardrop Pin
            ZStack {
                MarkerPinShape()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 38 : 32, height: isSelected ? 46 : 40)
                    .shadow(color: primaryColor.opacity(0.35), radius: isSelected ? 8 : 4, y: isSelected ? 4 : 2)
                    .overlay(
                        MarkerPinShape()
                            .stroke(Color.white, lineWidth: isSelected ? 2.5 : 2)
                    )

                // Bolt & Max Power inside bulb
                VStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: isSelected ? 14 : 12, weight: .bold))
                        .foregroundStyle(.white)

                    if let kw = maxKwText {
                        Text(kw)
                            .font(.system(size: 7.5, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .offset(y: isSelected ? -4 : -3.5)

                // Favorite Star Badge (Top-right corner)
                if station.isFavorite {
                    Circle()
                        .fill(Color(red: 254/255, green: 240/255, blue: 138/255))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Image(systemName: "star.fill")
                                .font(.system(size: 7.5))
                                .foregroundStyle(Color.orange)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .offset(x: isSelected ? 13 : 11, y: isSelected ? -15 : -13)
                }
            }

            // Clean Frosted Label Pill
            Text(station.name)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(.ultraThinMaterial)
                .background(Color(uiColor: .systemBackground).opacity(0.85))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1.5)
                .frame(maxWidth: 110)
        }
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected)
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
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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

