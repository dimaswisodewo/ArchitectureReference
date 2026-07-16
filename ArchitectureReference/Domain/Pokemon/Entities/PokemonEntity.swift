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

struct PokemonStatEntity: Identifiable, Equatable {
    let id: String
    let name: String
    let baseValue: Int

    var displayName: String { name.replacingOccurrences(of: "-", with: " ").capitalized }
}

struct PokemonDetailEntity: Identifiable, Equatable {
    let id: Int
    let name: String
    let artworkURL: URL?
    let types: [String]
    let abilities: [String]
    let height: Int
    let weight: Int
    let stats: [PokemonStatEntity]

    var displayName: String { name.replacingOccurrences(of: "-", with: " ").capitalized }
    var formattedID: String { String(format: "#%03d", id) }
    var formattedHeight: String { String(format: "%.1f m", Double(height) / 10.0) }
    var formattedWeight: String { String(format: "%.1f kg", Double(weight) / 10.0) }
}
