import Foundation

struct PokemonListResponseDTO: Decodable {
    let count: Int
    let next: URL?
    let previous: URL?
    let results: [PokemonListItemDTO]
}

struct PokemonListItemDTO: Decodable {
    let name: String
    let url: URL

    var identifier: Int? {
        Int(url.pathComponents.last { $0 != "/" } ?? "")
    }
}

struct PokemonDetailDTO: Decodable {
    let id: Int
    let name: String
    let sprites: PokemonSpritesDTO

    func toDomain() -> PokemonEntity {
        PokemonEntity(
            id: id,
            name: name,
            artworkURL: sprites.other.officialArtwork.frontDefault
        )
    }
}

struct PokemonSpritesDTO: Decodable {
    let other: PokemonOtherSpritesDTO
}

struct PokemonOtherSpritesDTO: Decodable {
    let officialArtwork: PokemonArtworkDTO

    enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

struct PokemonArtworkDTO: Decodable {
    let frontDefault: URL?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
    }
}
