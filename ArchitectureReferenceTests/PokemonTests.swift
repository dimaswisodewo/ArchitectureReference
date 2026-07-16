import XCTest
@testable import ArchitectureReference

final class PokemonDTOTests: XCTestCase {
    func testDecodingMapsListIdentifierAndDetailArtwork() throws {
        // Arrange
        let listJSON = #"{"count":1,"next":null,"previous":null,"results":[{"name":"bulbasaur","url":"https://pokeapi.co/api/v2/pokemon/1/"}]}"#
        let detailJSON = #"{"id":1,"name":"bulbasaur","height":7,"weight":69,"types":[{"slot":1,"type":{"name":"grass"}}],"abilities":[{"slot":1,"ability":{"name":"overgrow"}}],"stats":[{"base_stat":45,"stat":{"name":"hp"}}],"sprites":{"other":{"official-artwork":{"front_default":"https://example.com/1.png"}}}}"#

        // Act
        let list = try JSONDecoder().decode(PokemonListResponseDTO.self, from: Data(listJSON.utf8))
        let detail = try JSONDecoder().decode(PokemonDetailDTO.self, from: Data(detailJSON.utf8)).toDomain()

        // Assert
        XCTAssertEqual(list.results.first?.identifier, 1)
        XCTAssertEqual(detail.artworkURL?.absoluteString, "https://example.com/1.png")
        XCTAssertEqual(detail.types, ["grass"])
        XCTAssertEqual(detail.stats.first?.baseValue, 45)
    }
}

final class GetPokemonUseCaseTests: XCTestCase {
    func testExecuteForwardsValidPaginationToRepository() async throws {
        // Arrange
        let expectedPage = PokemonPage(pokemon: [.fixture()], nextOffset: 20)
        let repository = PokemonRepositorySpy(pageResult: .success(expectedPage))
        let useCase = GetPokemonUseCase(repository: repository)

        // Act
        let page = try await useCase.execute(limit: 20, offset: 40)

        // Assert
        XCTAssertEqual(page, expectedPage)
        XCTAssertEqual(repository.receivedPageRequests, [.init(limit: 20, offset: 40)])
    }

    func testExecuteRejectsInvalidPagination() async {
        // Arrange
        let repository = PokemonRepositorySpy(pageResult: .failure(TestError.expected))
        let useCase = GetPokemonUseCase(repository: repository)

        // Act
        do {
            _ = try await useCase.execute(limit: 0, offset: -1)
            XCTFail("Expected invalid pagination to throw")
        } catch {
            guard case PokemonDomainError.invalidPagination = error else {
                return XCTFail("Expected invalidPagination, received \(error)")
            }
        }

        // Assert
        XCTAssertTrue(repository.receivedPageRequests.isEmpty)
    }

    func testDetailExecuteRejectsInvalidIdentifier() async {
        // Arrange
        let repository = PokemonRepositorySpy(pageResult: .failure(TestError.expected))
        let useCase = GetPokemonDetailUseCase(repository: repository)

        // Act
        do {
            _ = try await useCase.execute(identifier: 0)
            XCTFail("Expected invalid identifier to throw")
        } catch {
            guard case PokemonDomainError.invalidIdentifier = error else {
                return XCTFail("Expected invalidIdentifier, received \(error)")
            }
        }

        // Assert
        XCTAssertTrue(repository.receivedDetailIdentifiers.isEmpty)
    }
}

final class PokemonRepositoryTests: XCTestCase {
    func testFetchPagePreservesListOrderAndPagination() async throws {
        // Arrange
        let remoteDataSource = PokemonRemoteDataSourceStub(
            list: .fixture(next: URL(string: "https://pokeapi.co/api/v2/pokemon?offset=2&limit=2")),
            details: [1: .fixture(id: 1), 2: .fixture(id: 2, name: "ivysaur")]
        )
        let repository = PokemonRepositoryImpl(remoteDataSource: remoteDataSource)

        // Act
        let page = try await repository.fetchPokemonPage(limit: 2, offset: 0)

        // Assert
        XCTAssertEqual(page.pokemon.map(\.id), [1, 2])
        XCTAssertEqual(page.nextOffset, 2)
        XCTAssertTrue(page.hasMore)
    }

    func testFetchPageKeepsSummaryWhenDetailFails() async throws {
        // Arrange
        let remoteDataSource = PokemonRemoteDataSourceStub(list: .fixture(resultCount: 1), details: [:])
        let repository = PokemonRepositoryImpl(remoteDataSource: remoteDataSource)

        // Act
        let page = try await repository.fetchPokemonPage(limit: 20, offset: 0)

        // Assert
        XCTAssertEqual(page.pokemon, [.fixture()])
        XCTAssertFalse(page.hasMore)
    }

    func testFetchDetailMapsRemoteDTO() async throws {
        // Arrange
        let remoteDataSource = PokemonRemoteDataSourceStub(
            list: .fixture(resultCount: 0),
            details: [1: .fixture()]
        )
        let repository = PokemonRepositoryImpl(remoteDataSource: remoteDataSource)

        // Act
        let detail = try await repository.fetchPokemonDetail(identifier: 1)

        // Assert
        XCTAssertEqual(detail.id, 1)
        XCTAssertEqual(detail.name, "bulbasaur")
    }
}

@MainActor
final class PokemonViewModelTests: XCTestCase {
    func testLoadInitialPageShowsPokemonOnSuccess() async {
        // Arrange
        let expectedPokemon = [PokemonEntity.fixture()]
        let useCase = PokemonUseCaseStub(results: [
            .success(PokemonPage(pokemon: expectedPokemon, nextOffset: nil))
        ])
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase)

        // Act
        await viewModel.loadInitialPage()

        // Assert
        XCTAssertEqual(viewModel.state.data, expectedPokemon)
        XCTAssertEqual(useCase.receivedRequests, [.init(limit: 20, offset: 0)])
    }

    func testLoadInitialPageShowsFailureOnError() async {
        // Arrange
        let useCase = PokemonUseCaseStub(results: [.failure(TestError.expected)])
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase)

        // Act
        await viewModel.loadInitialPage()

        // Assert
        XCTAssertNotNil(viewModel.state.error)
        XCTAssertNil(viewModel.state.data)
    }

    func testPaginationAppendsOnlyUniquePokemonAndStopsAtLastPage() async {
        // Arrange
        let useCase = PokemonUseCaseStub(results: [
            .success(PokemonPage(pokemon: [.fixture(id: 1), .fixture(id: 2)], nextOffset: 2)),
            .success(PokemonPage(pokemon: [.fixture(id: 2), .fixture(id: 3)], nextOffset: nil))
        ])
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase, pageSize: 2)

        // Act
        await viewModel.loadInitialPage()
        await viewModel.loadNextPageIfNeeded(currentItem: .fixture(id: 2))
        await viewModel.retryNextPage()

        // Assert
        XCTAssertEqual(viewModel.state.data?.map(\.id), [1, 2, 3])
        XCTAssertEqual(useCase.receivedRequests.count, 2)
    }

    func testPaginationKeepsExistingPokemonOnError() async {
        // Arrange
        let useCase = PokemonUseCaseStub(results: [
            .success(PokemonPage(pokemon: [.fixture()], nextOffset: 1)),
            .failure(TestError.expected)
        ])
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase, pageSize: 1)

        // Act
        await viewModel.loadInitialPage()
        await viewModel.loadNextPageIfNeeded(currentItem: .fixture())

        // Assert
        XCTAssertEqual(viewModel.state.data, [.fixture()])
        XCTAssertEqual(viewModel.paginationErrorMessage, TestError.expected.localizedDescription)
    }

    func testSelectForwardsPokemonToNavigator() {
        // Arrange
        let pokemon = PokemonEntity.fixture()
        let useCase = PokemonUseCaseStub(results: [])
        let navigator = PokemonNavigatorSpy()
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase, navigator: navigator)

        // Act
        viewModel.select(pokemon)

        // Assert
        XCTAssertEqual(navigator.selectedPokemon, pokemon)
    }
}

@MainActor
final class PokemonDetailViewModelTests: XCTestCase {
    func testLoadShowsDetailOnSuccess() async {
        // Arrange
        let expectedDetail = PokemonDetailEntity.fixture()
        let useCase = PokemonDetailUseCaseStub(result: .success(expectedDetail))
        let viewModel = PokemonDetailViewModel(summary: .fixture(), useCase: useCase)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertEqual(viewModel.state.data, expectedDetail)
        XCTAssertEqual(useCase.receivedIdentifiers, [1])
    }

    func testLoadShowsFailureOnError() async {
        // Arrange
        let useCase = PokemonDetailUseCaseStub(result: .failure(TestError.expected))
        let viewModel = PokemonDetailViewModel(summary: .fixture(), useCase: useCase)

        // Act
        await viewModel.load()

        // Assert
        XCTAssertNotNil(viewModel.state.error)
    }
}

private final class PokemonRepositorySpy: PokemonRepositoryProtocol {
    struct PageRequest: Equatable { let limit: Int; let offset: Int }

    let pageResult: Result<PokemonPage, Error>
    var detailResult: Result<PokemonDetailEntity, Error> = .failure(TestError.expected)
    private(set) var receivedPageRequests: [PageRequest] = []
    private(set) var receivedDetailIdentifiers: [Int] = []

    init(pageResult: Result<PokemonPage, Error>) { self.pageResult = pageResult }

    func fetchPokemonPage(limit: Int, offset: Int) async throws -> PokemonPage {
        receivedPageRequests.append(.init(limit: limit, offset: offset))
        return try pageResult.get()
    }

    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailEntity {
        receivedDetailIdentifiers.append(identifier)
        return try detailResult.get()
    }
}

private final class PokemonRemoteDataSourceStub: PokemonRemoteDataSourceProtocol {
    let list: PokemonListResponseDTO
    let details: [Int: PokemonDetailDTO]

    init(list: PokemonListResponseDTO, details: [Int: PokemonDetailDTO]) {
        self.list = list
        self.details = details
    }

    func fetchPokemonList(limit: Int, offset: Int) async throws -> PokemonListResponseDTO { list }

    func fetchPokemonDetail(identifier: Int) async throws -> PokemonDetailDTO {
        guard let detail = details[identifier] else { throw TestError.expected }
        return detail
    }
}

private final class PokemonUseCaseStub: GetPokemonUseCaseProtocol {
    struct Request: Equatable { let limit: Int; let offset: Int }

    private var results: [Result<PokemonPage, Error>]
    private(set) var receivedRequests: [Request] = []

    init(results: [Result<PokemonPage, Error>]) { self.results = results }

    func execute(limit: Int, offset: Int) async throws -> PokemonPage {
        receivedRequests.append(.init(limit: limit, offset: offset))
        guard !results.isEmpty else { throw TestError.expected }
        return try results.removeFirst().get()
    }
}

private final class PokemonDetailUseCaseStub: GetPokemonDetailUseCaseProtocol {
    let result: Result<PokemonDetailEntity, Error>
    private(set) var receivedIdentifiers: [Int] = []

    init(result: Result<PokemonDetailEntity, Error>) { self.result = result }

    func execute(identifier: Int) async throws -> PokemonDetailEntity {
        receivedIdentifiers.append(identifier)
        return try result.get()
    }
}

private final class PokemonNavigatorSpy: PokemonNavigator {
    private(set) var selectedPokemon: PokemonEntity?

    @MainActor
    func navigateToPokemonDetail(_ pokemon: PokemonEntity) { selectedPokemon = pokemon }
    func dismiss(animated: Bool) {}
    func pop(animated: Bool) {}
}

private extension PokemonListResponseDTO {
    static func fixture(
        next: URL? = nil,
        resultCount: Int = 2
    ) -> PokemonListResponseDTO {
        let allResults = [
            PokemonListItemDTO(name: "bulbasaur", url: URL(string: "https://pokeapi.co/api/v2/pokemon/1/")!),
            PokemonListItemDTO(name: "ivysaur", url: URL(string: "https://pokeapi.co/api/v2/pokemon/2/")!)
        ]
        return PokemonListResponseDTO(
            count: resultCount,
            next: next,
            previous: nil,
            results: Array(allResults.prefix(resultCount))
        )
    }
}
