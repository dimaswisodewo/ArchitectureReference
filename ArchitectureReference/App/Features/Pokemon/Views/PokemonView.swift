import SwiftUI

struct PokemonView: View {
    @ObservedObject var viewModel: PokemonViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if let pokemon = viewModel.state.data {
                pokemonGrid(pokemon)
            } else {
                fallbackView
            }
        }
        .navigationTitle("Pokédex")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if case .idle = viewModel.state {
                await viewModel.loadInitialPage()
            }
        }
    }

    private func pokemonGrid(_ pokemon: [PokemonEntity]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(pokemon) { item in
                    PokemonCardView(pokemon: item)
                        .task {
                            await viewModel.loadNextPageIfNeeded(currentItem: item)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            paginationFooter
                .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.isLoadingNextPage {
            ProgressView("Loading more Pokémon…")
        } else if let message = viewModel.paginationErrorMessage {
            VStack(spacing: 10) {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await viewModel.retryNextPage() }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.4)
                Text("Loading Pokémon…")
                    .foregroundColor(.secondary)
            }
        case .failure(let error, _):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.orange)
                Text("Couldn’t Load Pokémon")
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await viewModel.loadInitialPage() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
        case .success:
            EmptyView()
        }
    }
}

private struct PokemonCardView: View {
    let pokemon: PokemonEntity

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: pokemon.artworkURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text(pokemon.formattedID)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Text(pokemon.displayName)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private var placeholder: some View {
        Image(systemName: "questionmark.circle.fill")
            .resizable()
            .scaledToFit()
            .padding(30)
            .foregroundColor(.secondary)
    }
}
