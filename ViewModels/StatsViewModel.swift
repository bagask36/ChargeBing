import Foundation

@Observable
final class StatsViewModel {
    var stats: StatsSummary?
    var isLoading: Bool = false
    var errorMessage: String?

    @MainActor
    func fetchStats() async {
        isLoading = true
        errorMessage = nil

        do {
            let data: StatsSummary = try await APIClient.shared.request(path: "/stats/summary")
            self.stats = data
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}

