import Foundation

protocol PokemonRepositoryProtocol {
    func fetchPokemonPage(limit: Int, offset: Int) async throws -> PokemonPage
    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailEntity
}
