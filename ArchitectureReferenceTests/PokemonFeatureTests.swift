import XCTest
import UIKit
@testable import ArchitectureReference

final class PokemonFeatureTests: XCTestCase {
    func testListAndDetailDTOsDecodeOfficialArtwork() throws {
        let listData = Data(#"{"count":1,"next":null,"previous":null,"results":[{"name":"bulbasaur","url":"https://pokeapi.co/api/v2/pokemon/1/"}]}"#.utf8)
        let detailData = Data(#"{"id":1,"name":"bulbasaur","sprites":{"other":{"official-artwork":{"front_default":"https://example.com/1.png"}}}}"#.utf8)

        let list = try JSONDecoder().decode(PokemonListResponseDTO.self, from: listData)
        let detail = try JSONDecoder().decode(PokemonDetailDTO.self, from: detailData)

        XCTAssertEqual(list.results.first?.identifier, 1)
        XCTAssertEqual(detail.toDomain().artworkURL?.absoluteString, "https://example.com/1.png")
    }

    func testRepositoryPreservesListOrderAndPagination() async throws {
        let remote = PokemonRemoteDataSourceStub(
            list: PokemonListResponseDTO(
                count: 3,
                next: URL(string: "https://pokeapi.co/api/v2/pokemon?offset=2&limit=2"),
                previous: nil,
                results: [
                    PokemonListItemDTO(name: "bulbasaur", url: URL(string: "https://pokeapi.co/api/v2/pokemon/1/")!),
                    PokemonListItemDTO(name: "ivysaur", url: URL(string: "https://pokeapi.co/api/v2/pokemon/2/")!)
                ]
            ),
            details: [
                1: PokemonDetailDTO(id: 1, name: "bulbasaur", sprites: .stub),
                2: PokemonDetailDTO(id: 2, name: "ivysaur", sprites: .stub)
            ]
        )

        let page = try await PokemonRepositoryImpl(remoteDataSource: remote)
            .fetchPokemonPage(limit: 2, offset: 0)

        XCTAssertEqual(page.pokemon.map(\.id), [1, 2])
        XCTAssertEqual(page.nextOffset, 2)
        XCTAssertTrue(page.hasMore)
    }

    func testRepositoryKeepsItemWhenDetailFails() async throws {
        let remote = PokemonRemoteDataSourceStub(
            list: PokemonListResponseDTO(
                count: 1,
                next: nil,
                previous: nil,
                results: [PokemonListItemDTO(name: "bulbasaur", url: URL(string: "https://pokeapi.co/api/v2/pokemon/1/")!)]
            ),
            details: [:]
        )

        let page = try await PokemonRepositoryImpl(remoteDataSource: remote)
            .fetchPokemonPage(limit: 20, offset: 0)

        XCTAssertEqual(page.pokemon, [PokemonEntity(id: 1, name: "bulbasaur", artworkURL: nil)])
        XCTAssertFalse(page.hasMore)
    }

    @MainActor
    func testViewModelAppendsUniquePagesAndStopsAtLastPage() async {
        let useCase = GetPokemonUseCaseStub(results: [
            .success(PokemonPage(
                pokemon: [.stub(id: 1), .stub(id: 2)],
                nextOffset: 2
            )),
            .success(PokemonPage(
                pokemon: [.stub(id: 2), .stub(id: 3)],
                nextOffset: nil
            ))
        ])
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase, pageSize: 2)

        await viewModel.loadInitialPage()
        await viewModel.loadNextPageIfNeeded(currentItem: .stub(id: 2))
        await viewModel.retryNextPage()

        XCTAssertEqual(viewModel.state.data?.map(\.id), [1, 2, 3])
        XCTAssertEqual(useCase.requests.count, 2)
    }

    @MainActor
    func testViewModelKeepsExistingDataWhenNextPageFails() async {
        let useCase = GetPokemonUseCaseStub(results: [
            .success(PokemonPage(pokemon: [.stub(id: 1)], nextOffset: 1)),
            .failure(TestError.failed)
        ])
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase, pageSize: 1)

        await viewModel.loadInitialPage()
        await viewModel.loadNextPageIfNeeded(currentItem: .stub(id: 1))

        XCTAssertEqual(viewModel.state.data?.map(\.id), [1])
        XCTAssertNotNil(viewModel.paginationErrorMessage)
    }
}

final class DependencyAssemblyTests: XCTestCase {
    func testCoreAssemblyReturnsSameNetworkClientInstance() throws {
        let container = DependencyContainer()
        ArchitectureReferenceApp.setupDependencies(in: container)

        let first: NetworkClient = try container.resolve()
        let second: NetworkClient = try container.resolve()

        XCTAssertTrue(
            (first as! URLSessionNetworkClient) === (second as! URLSessionNetworkClient)
        )
    }

    func testPokemonDependenciesResolveAfterCoreSetup() throws {
        let container = DependencyContainer()
        ArchitectureReferenceApp.setupDependencies(in: container)
        let navigator = PokemonNavigatorStub()
        PokemonAssembly(navigator: navigator).assemble(container: container)

        let remoteDataSource: PokemonRemoteDataSourceProtocol = try container.resolve()
        let repository: PokemonRepositoryProtocol = try container.resolve()
        let useCase: GetPokemonUseCaseProtocol = try container.resolve()

        XCTAssertTrue(remoteDataSource is PokemonRemoteDataSourceImpl)
        XCTAssertTrue(repository is PokemonRepositoryImpl)
        XCTAssertTrue(useCase is GetPokemonUseCase)
    }

    func testPokemonDependencyResolutionFailsWithoutCoreSetup() {
        let container = DependencyContainer()
        let navigator = PokemonNavigatorStub()
        PokemonAssembly(navigator: navigator).assemble(container: container)

        XCTAssertThrowsError(try container.resolve() as PokemonRemoteDataSourceProtocol) { error in
            guard case DIError.missingDependency = error else {
                return XCTFail("Expected DIError.missingDependency, received \(error)")
            }
        }
    }
}

private final class PokemonRemoteDataSourceStub: PokemonRemoteDataSourceProtocol {
    let list: PokemonListResponseDTO
    let details: [Int: PokemonDetailDTO]

    init(list: PokemonListResponseDTO, details: [Int: PokemonDetailDTO]) {
        self.list = list
        self.details = details
    }

    func fetchPokemonList(limit: Int, offset: Int) async throws -> PokemonListResponseDTO {
        list
    }

    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailDTO {
        guard let detail = details[identifier] else { throw TestError.failed }
        return detail
    }
}

private final class PokemonNavigatorStub: PokemonNavigator {
    func dismiss(animated: Bool) {}
    func pop(animated: Bool) {}
}

private final class GetPokemonUseCaseStub: GetPokemonUseCaseProtocol {
    var results: [Result<PokemonPage, Error>]
    var requests: [(limit: Int, offset: Int)] = []

    init(results: [Result<PokemonPage, Error>]) {
        self.results = results
    }

    func execute(limit: Int, offset: Int) async throws -> PokemonPage {
        requests.append((limit, offset))
        return try results.removeFirst().get()
    }
}

private enum TestError: Error {
    case failed
}

private extension PokemonEntity {
    static func stub(id: Int) -> PokemonEntity {
        PokemonEntity(id: id, name: "pokemon-\(id)", artworkURL: nil)
    }
}

private extension PokemonSpritesDTO {
    static let stub = PokemonSpritesDTO(
        other: PokemonOtherSpritesDTO(
            officialArtwork: PokemonArtworkDTO(frontDefault: URL(string: "https://example.com/artwork.png"))
        )
    )
}
