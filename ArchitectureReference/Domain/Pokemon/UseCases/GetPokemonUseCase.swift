import Foundation

protocol GetPokemonUseCaseProtocol {
    func execute(limit: Int, offset: Int) async throws -> PokemonPage
}

final class GetPokemonUseCase: GetPokemonUseCaseProtocol {
    private let repository: PokemonRepositoryProtocol

    init(repository: PokemonRepositoryProtocol) {
        self.repository = repository
    }

    func execute(limit: Int = 20, offset: Int = 0) async throws -> PokemonPage {
        guard limit > 0, offset >= 0 else {
            throw PokemonDomainError.invalidPagination
        }
        return try await repository.fetchPokemonPage(limit: limit, offset: offset)
    }
}

enum PokemonDomainError: LocalizedError {
    case invalidPagination

    var errorDescription: String? {
        "The requested Pokémon page is invalid."
    }
}
