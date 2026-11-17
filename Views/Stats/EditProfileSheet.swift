import SwiftUI

struct EditProfileSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var evModelsVM = EvModelsViewModel()
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedEvModelId: Int? = nil

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Avatar & Preview Header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.emerald.opacity(0.15))
                                .frame(width: 64, height: 64)

                            Text(name.trimmingCharacters(in: .whitespaces).prefix(1).uppercased().isEmpty ? "U" : name.trimmingCharacters(in: .whitespaces).prefix(1).uppercased())
                                .font(.title.bold())
                                .foregroundStyle(Color.emerald)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "Nama Pengguna" : name)
                                .font(.headline)
                                .lineLimit(1)

                            Text(email.isEmpty ? "email@chargebing.local" : email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if let selectedId = selectedEvModelId,
                               let model = evModelsVM.models.first(where: { $0.id == selectedId }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "car.side.fill")
                                        .font(.system(size: 9))
                                    Text(model.fullName)
                                        .font(.caption2.bold())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.emerald.opacity(0.12))
                                .foregroundStyle(Color.emerald)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 6)
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

                // MARK: - Ganti Password (Opsional)
                Section(header: Text("Keamanan & Password"), footer: Text("Kosongkan kolom password jika Anda tidak ingin mengubah password akun.")) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.emerald)
                            .frame(width: 22)
                        SecureField("Password Baru (Opsional, min. 8 karakter)", text: $password)
                            .textContentType(.newPassword)
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
            .alert("Profil Diperbarui", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Data profil akun Anda berhasil disimpan.")
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
            let result = await authVM.updateProfile(
                name: name,
                email: email,
                password: password.isEmpty ? nil : password,
                evModelId: selectedEvModelId
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

