import Foundation
@testable import ArchitectureReference

enum TestError: LocalizedError {
    case expected

    var errorDescription: String? { "Expected test error" }
}

extension PokemonEntity {
    static func fixture(
        id: Int = 1,
        name: String = "bulbasaur",
        artworkURL: URL? = nil
    ) -> PokemonEntity {
        PokemonEntity(id: id, name: name, artworkURL: artworkURL)
    }
}

extension PokemonDetailEntity {
    static func fixture(id: Int = 1, name: String = "bulbasaur") -> PokemonDetailEntity {
        PokemonDetailEntity(
            id: id,
            name: name,
            artworkURL: nil,
            types: ["grass"],
            abilities: ["overgrow"],
            height: 7,
            weight: 69,
            stats: [PokemonStatEntity(id: "hp", name: "hp", baseValue: 45)]
        )
    }
}

extension PokemonSpritesDTO {
    static func fixture(artworkURL: URL? = URL(string: "https://example.com/artwork.png")) -> PokemonSpritesDTO {
        PokemonSpritesDTO(
            other: PokemonOtherSpritesDTO(
                officialArtwork: PokemonArtworkDTO(frontDefault: artworkURL)
            )
        )
    }
}

extension PokemonDetailDTO {
    static func fixture(id: Int = 1, name: String = "bulbasaur") -> PokemonDetailDTO {
        PokemonDetailDTO(
            id: id,
            name: name,
            sprites: .fixture(),
            types: [],
            abilities: [],
            height: 7,
            weight: 69,
            stats: []
        )
    }
}

extension ProfileEntity {
    static func fixture(
        id: String = "1089",
        email: String = "developer@apple.com",
        firstName: String = "Dimas",
        lastName: String = "Wisodewo"
    ) -> ProfileEntity {
        ProfileEntity(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: "+6281122334455",
            address: "Jakarta",
            birthDate: "1994-08-23",
            position: "iOS Engineer",
            avatarUrl: URL(string: "https://example.com/avatar.png")
        )
    }
}

extension ProfileDTO {
    static func fixture(email: String? = "developer@apple.com") -> ProfileDTO {
        ProfileDTO(
            id: 1089,
            userid: "APPLE-ID-99281",
            email: email,
            firstName: "Dimas",
            lastName: "Wisodewo",
            phoneNumber: "+6281122334455",
            address: "Jakarta",
            birthDate: "1994-08-23",
            position: "iOS Engineer",
            avatar: "https://example.com/avatar.png"
        )
    }
}
