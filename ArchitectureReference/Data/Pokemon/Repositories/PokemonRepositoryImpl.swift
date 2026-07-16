import Foundation

final class PokemonRepositoryImpl: PokemonRepositoryProtocol {
    private let remoteDataSource: PokemonRemoteDataSourceProtocol

    init(remoteDataSource: PokemonRemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchPokemonPage(limit: Int, offset: Int) async throws -> PokemonPage {
        let response = try await remoteDataSource.fetchPokemonList(limit: limit, offset: offset)
        let pokemon = try await enrich(response.results, startingAt: offset)

        let nextOffset = response.next == nil ? nil : offset + response.results.count
        return PokemonPage(pokemon: pokemon, nextOffset: nextOffset)
    }

    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailEntity {
        try await remoteDataSource.fetchPokemonDetail(identifier: identifier).toDomain()
    }

    private func enrich(
        _ items: [PokemonListItemDTO],
        startingAt offset: Int
    ) async throws -> [PokemonEntity] {
        try await withThrowingTaskGroup(
            of: (index: Int, pokemon: PokemonEntity).self
        ) { group in
            for (index, item) in items.enumerated() {
                // Every detail request is independent, so a task group lets the
                // requests run at the same time instead of waiting one by one.
                group.addTask { [remoteDataSource] in
                    let pokemon = try await Self.enrich(
                        item,
                        fallbackID: offset + index + 1,
                        using: remoteDataSource
                    )

                    // Tasks can finish in any order. Keep the original index so
                    // the final page can be restored to the API's list order.
                    return (index, pokemon)
                }
            }

            var indexedPokemon: [(index: Int, pokemon: PokemonEntity)] = []
            for try await result in group {
                indexedPokemon.append(result)
            }

            return indexedPokemon
                .sorted { $0.index < $1.index }
                .map(\.pokemon)
        }
    }

    private static func enrich(
        _ item: PokemonListItemDTO,
        fallbackID: Int,
        using remoteDataSource: PokemonRemoteDataSourceProtocol
    ) async throws -> PokemonEntity {
        // The identifier normally comes from the URL returned by the list API.
        // If that URL is malformed, use its position in the requested page.
        guard let identifier = item.identifier else {
            return item.fallbackEntity(id: fallbackID)
        }

        do {
            let detail = try await remoteDataSource.fetchPokemonDetail(identifier: identifier)
            return PokemonEntity(
                id: detail.id,
                name: detail.name,
                artworkURL: detail.sprites.other.officialArtwork.frontDefault
            )
        } catch {
            // Cancellation means the caller no longer needs this page, so it
            // must stop the whole operation rather than create fallback data.
            try Task.checkCancellation()

            // A normal detail failure should not discard the entire page. The
            // list response still has enough information to display the card.
            return item.fallbackEntity(id: identifier)
        }
    }
}

private extension PokemonListItemDTO {
    func fallbackEntity(id: Int) -> PokemonEntity {
        PokemonEntity(id: id, name: name, artworkURL: nil)
    }
}
