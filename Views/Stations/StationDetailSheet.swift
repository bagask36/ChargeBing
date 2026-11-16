import SwiftUI
import MapKit

struct StationDetailSheet: View {
    let station: Station
    let onToggleFavorite: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showAddSessionSheet = false
    @State private var selectedConnectorForSession: Connector? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.name)
                                    .font(.title3.bold())

                                Text(station.operatorName ?? "Operator Mandiri")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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

                        Text(station.address ?? "Alamat tidak tersedia")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let dist = station.distanceKm {
                            HStack(spacing: 4) {
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

                    // Quick Actions (Navigate Route & Log Session)
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Button {
                                openMapNavigation(to: station)
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    Text("Rute Apple Maps")
                                }
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.emerald)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if let googleUrl = URL(string: "comgooglemaps://?daddr=\(station.latitude),\(station.longitude)&directionsmode=driving"),
                               UIApplication.shared.canOpenURL(googleUrl) {
                                Button {
                                    UIApplication.shared.open(googleUrl)
                                } label: {
                                    HStack {
                                        Image(systemName: "map.fill")
                                        Text("Google Maps")
                                    }
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        // Catat Sesi Pengisian Button
                        Button {
                            selectedConnectorForSession = nil
                            showAddSessionSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "bolt.badge.plus.fill")
                                Text("Catat Sesi Charging di Sini")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.emerald.opacity(0.12))
                            .foregroundStyle(Color.emerald)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        let placemark = MKPlacemark(coordinate: station.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = station.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
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

