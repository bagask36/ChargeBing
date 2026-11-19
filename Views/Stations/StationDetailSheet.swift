import SwiftUI
import MapKit

struct StationDetailSheet: View {
    let station: Station
    let onToggleFavorite: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showAddSessionSheet = false
    @State private var selectedConnectorForSession: Connector? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.name)
                                    .font(.title3.bold())

                                HStack(spacing: 8) {
                                    Text(station.operatorName ?? "Operator Mandiri")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text(station.gbtStatus.title)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.emerald.opacity(0.12))
                                        .foregroundStyle(Color.emerald)
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()

                            Button {
                                onToggleFavorite()
                            } label: {
                                Image(systemName: station.isFavorite ? "star.fill" : "star")
                                    .font(.title3)
                                    .foregroundStyle(station.isFavorite ? .yellow : .secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)

                            Text(station.address ?? "Alamat tidak tersedia")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let dist = station.distanceKm {
                            HStack(spacing: 5) {
                                Image(systemName: "location.fill")
                                Text("Jarak: \(Formatters.distance(dist)) dari posisi mobil Anda")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(Color.emerald)
                            .padding(.top, 2)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Primary Actions Bar (Petunjuk Arah & Catat Sesi)
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            // Menu Navigasi Peta (Apple Maps / Google Maps)
                            Menu {
                                Button {
                                    openMapNavigation(to: station)
                                } label: {
                                    Label("Apple Maps", systemImage: "map")
                                }

                                if let googleUrl = URL(string: "comgooglemaps://?daddr=\(station.latitude),\(station.longitude)&directionsmode=driving") {
                                    Button {
                                        openURL(googleUrl) { accepted in
                                            if !accepted, let webUrl = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(station.latitude),\(station.longitude)") {
                                                openURL(webUrl)
                                            }
                                        }
                                    } label: {
                                        Label("Google Maps", systemImage: "arrow.triangle.turn.up.right.diamond")
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    Text("Petunjuk Arah")
                                    Image(systemName: "chevron.down")
                                        .font(.caption2.bold())
                                }
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.emerald)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Catat Sesi Pengisian Button
                            Button {
                                selectedConnectorForSession = nil
                                showAddSessionSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.badge.plus.fill")
                                    Text("Catat Sesi")
                                }
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }

                        // Kartu Aplikasi Charging Resmi (PLN Mobile, Voltron, Terra Charge, E-Charge)
                        if let app = station.resolvedChargingApp {
                            Button {
                                openChargingApp(app)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.emerald.opacity(0.12))
                                            .frame(width: 42, height: 42)

                                        Image(systemName: "bolt.fill")
                                            .font(.headline)
                                            .foregroundStyle(Color.emerald)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                    }

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Text("Buka")
                                            .font(.caption.bold())
                                        Image(systemName: "arrow.up.forward.app.fill")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(Color.emerald)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.emerald.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.emerald.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Available Connectors (Colokan)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Konektor & Colokan Tersedia")
                                .font(.headline)
                            Spacer()
                            Text("Pilih colokan untuk mencatat")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let connectors = station.connectors, !connectors.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(connectors) { conn in
                                    ConnectorItemRow(connector: conn) {
                                        selectedConnectorForSession = conn
                                        showAddSessionSheet = true
                                    }
                                }
                            }
                        } else {
                            Text("Belum ada data konektor untuk stasiun ini.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Operational Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Informasi Operasional & Tarif")
                            .font(.headline)

                        VStack(spacing: 10) {
                            InfoRow(icon: "clock.fill", title: "Jam Buka", value: station.openingHours ?? "24 Jam")
                            Divider()
                            InfoRow(icon: "tag.fill", title: "Estimasi Biaya", value: station.pricingNote ?? "Tarif standar PLN / Operator")
                            if let notes = station.notes, !notes.isEmpty {
                                Divider()
                                InfoRow(icon: "info.circle.fill", title: "Catatan Lokasi", value: notes)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .navigationTitle("Detail SPKLU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSessionSheet) {
                AddSessionSheet(
                    preselectedStation: station,
                    preselectedConnector: selectedConnectorForSession
                ) {
                    dismiss()
                }
            }
        }
    }

    private func openMapNavigation(to station: Station) {
        let location = CLLocation(latitude: station.latitude, longitude: station.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = station.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openChargingApp(_ app: ChargingApp) {
        // Kumpulkan skema kandidat yang mungkin didaftarkan oleh aplikasi
        var candidateSchemes: [String] = []
        if let primary = app.schemeUrl, !primary.isEmpty {
            candidateSchemes.append(primary)
        }

        let appNameLower = app.name.lowercased()
        if appNameLower.contains("e charge") || appNameLower.contains("echarge") {
            for s in ["echarge://", "echargeglobal://", "echargeinternational://", "com.echargeglobal://"] {
                if !candidateSchemes.contains(s) { candidateSchemes.append(s) }
            }
        } else if appNameLower.contains("terra") {
            for s in ["terracharge://", "terra-charge://", "terrachargeid://", "terrachargehyperion://", "com.terracharge.hyperion://", "hyperion://"] {
                if !candidateSchemes.contains(s) { candidateSchemes.append(s) }
            }
        } else if appNameLower.contains("pln") {
            for s in ["plnmobile://", "pln://"] {
                if !candidateSchemes.contains(s) { candidateSchemes.append(s) }
            }
        } else if appNameLower.contains("voltron") {
            for s in ["voltron://"] {
                if !candidateSchemes.contains(s) { candidateSchemes.append(s) }
            }
        }

        // Cek apakah ada skema yang berhasil terdeteksi di perangkat pengguna
        for scheme in candidateSchemes {
            if let schemeUrl = URL(string: scheme),
               UIApplication.shared.canOpenURL(schemeUrl) {
                print("[ChargingApp] Berhasil menemukan skema: \(scheme), membuka aplikasi...")
                UIApplication.shared.open(schemeUrl)
                return
            }
        }

        // Fallback: Jika aplikasi tidak terpasang di perangkat / simulator, buka App Store
        if let storeStr = app.appStoreUrl,
           let storeUrl = URL(string: storeStr) {
            print("[ChargingApp] Aplikasi belum terpasang atau skema tidak cocok, membuka App Store: \(storeStr)")
            UIApplication.shared.open(storeUrl)
        } else if let firstScheme = candidateSchemes.first,
                  let fallbackUrl = URL(string: firstScheme) {
            UIApplication.shared.open(fallbackUrl)
        }
    }
}

// MARK: - Connector Item Row
struct ConnectorItemRow: View {
    let connector: Connector
    var onSelect: (() -> Void)? = nil

    var badgeColor: Color {
        switch connector.compatStatus {
        case "native": return Color.emerald
        case "adapter_ok": return Color.blue
        case "untested": return Color.orange
        default: return Color.red
        }
    }

    var body: some View {
        Button {
            onSelect?()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(connector.currentType) \(connector.plugType)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text("\(Int(connector.powerKw)) kW")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .systemFill))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }

                    if let note = connector.adapterNote, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(connector.compatStatus.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor.opacity(0.15))
                        .foregroundStyle(badgeColor)
                        .clipShape(Capsule())

                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.emerald)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Row Helper
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.emerald)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

