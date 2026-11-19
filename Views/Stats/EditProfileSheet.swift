import SwiftUI
import PhotosUI

struct EditProfileSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var evModelsVM = EvModelsViewModel()
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedEvModelId: Int? = nil

    // Foto Profil Picker State
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var avatarBase64: String? = nil
    @State private var hasChangedPhoto: Bool = false
    @State private var isRemovingPhoto: Bool = false

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert: Bool = false

    private var activeAvatarUrl: String? {
        if isRemovingPhoto { return nil }
        return avatarBase64 ?? authVM.currentUser?.avatarUrl
    }

    private var hasActiveAvatar: Bool {
        if isRemovingPhoto { return false }
        return selectedImage != nil || (authVM.currentUser?.avatarUrl != nil && !authVM.currentUser!.avatarUrl!.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Avatar & Foto Profil Section
                Section {
                    VStack(spacing: 14) {
                        ZStack(alignment: .bottomTrailing) {
                            UserAvatarView(
                                avatarUrl: activeAvatarUrl,
                                uiImage: isRemovingPhoto ? nil : selectedImage,
                                name: name,
                                size: 92,
                                showBorder: true
                            )

                            // Quick Camera Button on Avatar
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ZStack {
                                    Circle()
                                        .fill(Color.emerald)
                                        .frame(width: 32, height: 32)
                                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: 4)
                        }
                        .padding(.top, 4)

                        VStack(spacing: 6) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus")
                                    Text(hasActiveAvatar ? "Ganti Foto Profil" : "Pilih Foto Profil")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(Color.emerald)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.emerald.opacity(0.12))
                                .clipShape(Capsule())
                            }

                            if hasActiveAvatar {
                                Button(role: .destructive) {
                                    withAnimation {
                                        isRemovingPhoto = true
                                        selectedImage = nil
                                        avatarBase64 = ""
                                        hasChangedPhoto = true
                                        selectedPhotoItem = nil
                                    }
                                } label: {
                                    Text("Hapus Foto")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // MARK: - Informasi Akun
                Section("Informasi Akun") {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.emerald)
                            .frame(width: 22)
                        TextField("Nama Lengkap", text: $name)
                            .textContentType(.name)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Color.emerald)
                            .frame(width: 22)
                        TextField("Alamat Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                // MARK: - Mobil Listrik Aktif (EV Model)
                Section("Mobil Listrik Utama") {
                    if evModelsVM.isLoading && evModelsVM.models.isEmpty {
                        HStack {
                            ProgressView()
                                .tint(Color.emerald)
                            Text("Memuat katalog mobil...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Mobil Listrik", selection: $selectedEvModelId) {
                            Text("Belum Memilih Mobil").tag(nil as Int?)
                            ForEach(evModelsVM.models) { car in
                                Text("\(car.brand) \(car.modelName) \(car.variant ?? "") (\(car.rangeKm) km)")
                                    .tag(car.id as Int?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    if let selectedId = selectedEvModelId,
                       let car = evModelsVM.models.first(where: { $0.id == selectedId }) {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "battery.100percent")
                                    .font(.caption2)
                                    .foregroundStyle(Color.emerald)
                                Text("\(String(format: "%.1f", car.batteryCapacityKwh)) kWh")
                                    .font(.caption.bold())
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "road.lanes")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text("\(car.rangeKm) km (Jarak Tempuh)")
                                    .font(.caption.bold())
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                    }
                }

                // MARK: - Ganti Password (Opsional)
                Section(
                    header: Text("Keamanan & Password"),
                    footer: Text("Kosongkan kolom password jika Anda tidak ingin mengubah password akun.")
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.emerald)
                            .frame(width: 22)
                        SecureField("Password Baru (Opsional, min. 8 karakter)", text: $password)
                            .textContentType(.newPassword)
                    }
                }

                // Error Message Banner
                if let error = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // MARK: - Action Button
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 6)
                            }
                            Text(isSubmitting ? "Menyimpan..." : "Simpan Perubahan")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.emerald)
                    .disabled(isSubmitting || name.trimmingCharacters(in: .whitespaces).isEmpty || email.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Edit Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .onAppear {
                loadCurrentUserData()
            }
            .task {
                await evModelsVM.fetchModels()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        let resized = image.resized(toMaxDimension: 512)
                        if let jpegData = resized.jpegData(compressionQuality: 0.75) {
                            let base64String = "data:image/jpeg;base64," + jpegData.base64EncodedString()
                            await MainActor.run {
                                self.selectedImage = resized
                                self.avatarBase64 = base64String
                                self.hasChangedPhoto = true
                                self.isRemovingPhoto = false
                            }
                        }
                    }
                }
            }
            .alert("Profil Diperbarui", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Data profil akun dan foto Anda berhasil disimpan.")
            }
        }
    }

    private func loadCurrentUserData() {
        if let user = authVM.currentUser {
            name = user.name
            email = user.email
            selectedEvModelId = user.evModelId
        }
    }

    private func saveProfile() {
        errorMessage = nil
        isSubmitting = true

        Task {
            let avatarToSend: String?
            if hasChangedPhoto {
                avatarToSend = isRemovingPhoto ? "" : avatarBase64
            } else {
                avatarToSend = nil
            }

            let result = await authVM.updateProfile(
                name: name,
                email: email,
                password: password.isEmpty ? nil : password,
                evModelId: selectedEvModelId,
                avatar: avatarToSend
            )

            isSubmitting = false

            if result.success {
                showSuccessAlert = true
            } else {
                errorMessage = result.message ?? "Gagal menyimpan perubahan profil."
            }
        }
    }
}
