import Foundation

enum PokemonEndpoint: APIEndpoint {
    case list(limit: Int, offset: Int)
    case detail(identifier: Int)

    var baseURL: URL {
        URL(string: "https://pokeapi.co")!
    }

    var path: String {
        switch self {
        case .list:
            return "api/v2/pokemon"
        case .detail(let identifier):
            return "api/v2/pokemon/\(identifier)"
        }
    }

    var method: HTTPMethod { .get }
    var headers: [String: String]? { ["Accept": "application/json"] }

    var task: HTTPTask {
        switch self {
        case .list(let limit, let offset):
            return .requestParameters(
                parameters: ["limit": limit, "offset": offset],
                encoding: .url
            )
        case .detail:
            return .requestPlain
        }
    }
}

protocol PokemonRemoteDataSourceProtocol {
    func fetchPokemonList(limit: Int, offset: Int) async throws -> PokemonListResponseDTO
    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailDTO
}

final class PokemonRemoteDataSourceImpl: PokemonRemoteDataSourceProtocol {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

    func fetchPokemonList(limit: Int, offset: Int) async throws -> PokemonListResponseDTO {
        try await networkClient.request(PokemonEndpoint.list(limit: limit, offset: offset))
    }

    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailDTO {
        try await networkClient.request(PokemonEndpoint.detail(identifier: identifier))
    }
}
