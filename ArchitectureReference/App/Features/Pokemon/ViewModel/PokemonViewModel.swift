import Foundation
import Combine

@MainActor
final class PokemonViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[PokemonEntity]> = .idle
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var paginationErrorMessage: String?

    private let getPokemonUseCase: GetPokemonUseCaseProtocol
    private let pageSize: Int
    private var nextOffset: Int? = 0

    init(getPokemonUseCase: GetPokemonUseCaseProtocol, pageSize: Int = 20) {
        self.getPokemonUseCase = getPokemonUseCase
        self.pageSize = pageSize
    }

    func loadInitialPage() async {
        guard !state.isLoading else { return }

        state = .loading(previousData: nil)
        paginationErrorMessage = nil

        do {
            let page = try await getPokemonUseCase.execute(limit: pageSize, offset: 0)
            state = .success(page.pokemon)
            nextOffset = page.nextOffset
        } catch {
            state = .failure(error, previousData: nil)
            nextOffset = 0
        }
    }

    func loadNextPageIfNeeded(currentItem: PokemonEntity) async {
        guard let pokemon = state.data,
              let index = pokemon.firstIndex(where: { $0.id == currentItem.id }),
              index >= max(pokemon.count - 4, 0) else {
            return
        }
        await loadNextPage()
    }

    func retryNextPage() async {
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard !isLoadingNextPage, let offset = nextOffset, state.data != nil else { return }

        isLoadingNextPage = true
        paginationErrorMessage = nil
        defer { isLoadingNextPage = false }

        do {
            let page = try await getPokemonUseCase.execute(limit: pageSize, offset: offset)
            let existing = state.data ?? []
            let existingIDs = Set(existing.map(\.id))
            let uniqueNewPokemon = page.pokemon.filter { !existingIDs.contains($0.id) }
            state = .success(existing + uniqueNewPokemon)
            nextOffset = page.nextOffset
        } catch {
            paginationErrorMessage = error.localizedDescription
        }
    }
}
