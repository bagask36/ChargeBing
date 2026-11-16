import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM

    @State private var email = "admin@chargebing.local"
    @State private var password = "password123"
    @State private var isPasswordVisible = false
    @State private var showSettings = false
    @State private var customBaseURL = Config.baseURL

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    // Logo & Brand
                    VStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.emerald.opacity(0.35), radius: 12, y: 6)
                            .accessibilityLabel("Logo ChargeBing")

                        Text("ChargeBing")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("EV Personal Charging Station Tracker")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Input Form Card
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email Akun")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(Color.emerald)
                                    .frame(width: 20)

                                TextField("Masukkan email", text: $email)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(Color.emerald)
                                    .frame(width: 20)

                                if isPasswordVisible {
                                    TextField("Masukkan password", text: $password)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("Masukkan password", text: $password)
                                }

                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let error = authVM.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        }

                        // Submit Button
                        Button {
                            Task {
                                _ = await authVM.login(email: email, password: password)
                            }
                        } label: {
                            HStack {
                                if authVM.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Masuk ke ChargeBing")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.emerald)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.emerald.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                    .padding(.horizontal)

                    Spacer()

                    // Server endpoint settings
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                            Text("Server: \(Config.baseURL)")
                                .lineLimit(1)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 12)
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    Form {
                        Section("Konfigurasi Base URL Server") {
                            TextField("URL Backend (misal http://127.0.0.1:8080/api/v1)", text: $customBaseURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            Button("Simpan URL") {
                                Config.baseURL = customBaseURL
                                showSettings = false
                            }
                            .foregroundStyle(Color.emerald)

                            Button("Kembalikan ke Default Simulator") {
                                customBaseURL = Config.defaultBaseURL
                                Config.baseURL = Config.defaultBaseURL
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Pengaturan Server")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Tutup") { showSettings = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Color Extension for Emerald
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
}

