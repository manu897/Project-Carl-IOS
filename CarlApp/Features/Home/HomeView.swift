import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("My Plants")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // AddPlant flow lands in a follow-up commit.
                        Button {
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(true)
                    }
                }
        }
        .task {
            if viewModel.state == .idle { await viewModel.load() }
        }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading where viewModel.plants.isEmpty:
            ProgressView("Looking for plants…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message) where viewModel.plants.isEmpty:
            ContentUnavailableView(
                "Couldn't reach the hub",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
        default:
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.plants) { plant in
                    NavigationLink(value: plant) {
                        PlantCardView(plant: plant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationDestination(for: Plant.self) { plant in
            PlantDetailView(plant: plant)
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(repository: HubRepository(client: MockHubClient())))
}
