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
    let types: [PokemonTypeDTO]
    let abilities: [PokemonAbilityDTO]
    let height: Int
    let weight: Int
    let stats: [PokemonStatDTO]

    func toDomain() -> PokemonDetailEntity {
        PokemonDetailEntity(
            id: id,
            name: name,
            artworkURL: sprites.other.officialArtwork.frontDefault,
            types: types.sorted { $0.slot < $1.slot }.map { $0.type.name },
            abilities: abilities.sorted { $0.slot < $1.slot }.map { $0.ability.name },
            height: height,
            weight: weight,
            stats: stats.map { PokemonStatEntity(id: $0.stat.name, name: $0.stat.name, baseValue: $0.baseStat) }
        )
    }
}

struct PokemonTypeDTO: Decodable { let slot: Int; let type: PokemonNamedResourceDTO }
struct PokemonAbilityDTO: Decodable { let slot: Int; let ability: PokemonNamedResourceDTO }
struct PokemonNamedResourceDTO: Decodable { let name: String }
struct PokemonStatDTO: Decodable {
    let baseStat: Int
    let stat: PokemonNamedResourceDTO
    enum CodingKeys: String, CodingKey { case baseStat = "base_stat"; case stat }
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
