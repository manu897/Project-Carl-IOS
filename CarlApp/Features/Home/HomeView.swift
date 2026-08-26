import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingSettings = false
    @State private var showingAddPlant = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("My Plants")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingAddPlant = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(plants: viewModel.plants)
                }
                .sheet(isPresented: $showingAddPlant) {
                    AddPlantView(repository: viewModel.repository) {
                        Task { await viewModel.refresh() }
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
        case .idle:
            ProgressView("Looking for plants…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where viewModel.plants.isEmpty:
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
            VStack(spacing: 0) {
                if viewModel.isStale {
                    staleBanner
                }
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.plants) { plant in
                        NavigationLink(value: plant) {
                            PlantCardView(plant: plant)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, viewModel.isStale ? 8 : 12)
                .padding(.bottom, 12)

                if let lastUpdated = viewModel.lastUpdated, !viewModel.isStale {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
        }
        .navigationDestination(for: Plant.self) { plant in
            PlantDetailView(plant: plant)
        }
    }

    private var staleBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wifi.slash")
            VStack(alignment: .leading, spacing: 2) {
                Text("No recent data")
                    .font(.subheadline.weight(.medium))
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Last updated \(lastUpdated.formatted(.relative(presentation: .named))) — check your connection.")
                        .font(.caption)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.orange)
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(repository: HubRepository(client: MockHubClient())))
}
