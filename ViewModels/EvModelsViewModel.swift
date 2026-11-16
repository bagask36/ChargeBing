import Foundation

@Observable
final class EvModelsViewModel {
    var models: [EvModel] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedBrand: String = "ALL"

    var filteredModels: [EvModel] {
        var list = models

        if selectedBrand != "ALL" {
            list = list.filter { $0.brand == selectedBrand }
        }

        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.brand.lowercased().contains(query) ||
                $0.modelName.lowercased().contains(query) ||
                ($0.variant?.lowercased().contains(query) ?? false)
            }
        }

        return list
    }

    var availableBrands: [String] {
        let set = Set(models.map { $0.brand })
        return ["ALL"] + Array(set).sorted()
    }

    @MainActor
    func fetchModels() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: APIResponse<[EvModel]> = try await APIClient.shared.request(
                path: "/ev-models",
                queryItems: [
                    URLQueryItem(name: "all", value: "1"),
                    URLQueryItem(name: "active_only", value: "1")
                ]
            )
            self.models = response.data
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}

