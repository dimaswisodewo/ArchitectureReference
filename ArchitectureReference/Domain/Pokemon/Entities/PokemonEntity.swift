import Foundation

struct PokemonEntity: Identifiable, Equatable {
    let id: Int
    let name: String
    let artworkURL: URL?

    var displayName: String {
        name.replacingOccurrences(of: "-", with: " ").capitalized
    }

    var formattedID: String {
        String(format: "#%03d", id)
    }
}

struct PokemonPage: Equatable {
    let pokemon: [PokemonEntity]
    let nextOffset: Int?

    var hasMore: Bool { nextOffset != nil }
}
