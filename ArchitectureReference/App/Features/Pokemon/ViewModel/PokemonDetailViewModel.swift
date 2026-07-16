import Foundation
import Combine

@MainActor
final class PokemonDetailViewModel: ObservableObject {
    let summary: PokemonEntity
    @Published private(set) var state: ViewState<PokemonDetailEntity> = .idle
    private let useCase: GetPokemonDetailUseCaseProtocol

    init(summary: PokemonEntity, useCase: GetPokemonDetailUseCaseProtocol) {
        self.summary = summary
        self.useCase = useCase
    }

    func load() async {
        guard !state.isLoading else { return }
        state = .loading()
        do { state = .success(try await useCase.execute(identifier: summary.id)) }
        catch { state = .failure(error) }
    }
}
