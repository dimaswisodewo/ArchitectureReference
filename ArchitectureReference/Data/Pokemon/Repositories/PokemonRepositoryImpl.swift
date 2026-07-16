import Foundation

final class PokemonRepositoryImpl: PokemonRepositoryProtocol {
    private let remoteDataSource: PokemonRemoteDataSourceProtocol

    init(remoteDataSource: PokemonRemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchPokemonPage(limit: Int, offset: Int) async throws -> PokemonPage {
        let response = try await remoteDataSource.fetchPokemonList(limit: limit, offset: offset)

        let pokemon = await withTaskGroup(of: (Int, PokemonEntity).self) { group in
            for (index, item) in response.results.enumerated() {
                group.addTask { [remoteDataSource] in
                    guard let identifier = item.identifier else {
                        return (index, PokemonEntity(id: offset + index + 1, name: item.name, artworkURL: nil))
                    }

                    do {
                        let detail = try await remoteDataSource.fetchPokemonDetail(identifier: identifier)
                        return (index, PokemonEntity(id: detail.id, name: detail.name, artworkURL: detail.sprites.other.officialArtwork.frontDefault))
                    } catch {
                        return (index, PokemonEntity(id: identifier, name: item.name, artworkURL: nil))
                    }
                }
            }

            var indexedPokemon: [(Int, PokemonEntity)] = []
            for await result in group {
                indexedPokemon.append(result)
            }
            return indexedPokemon.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        let nextOffset = response.next == nil ? nil : offset + response.results.count
        return PokemonPage(pokemon: pokemon, nextOffset: nextOffset)
    }

    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailEntity {
        try await remoteDataSource.fetchPokemonDetail(identifier: identifier).toDomain()
    }
}
