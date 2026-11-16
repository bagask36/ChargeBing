import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authVM.isAuthenticated)
    }
}

