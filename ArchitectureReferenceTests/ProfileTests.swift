import XCTest
@testable import ArchitectureReference

final class ProfileDTOTests: XCTestCase {
    func testMappingUsesDomainDefaultsForMissingOptionalValues() {
        // Arrange
        let profile = ProfileDTO.fixture(email: nil).toDomain()

        // Act
        let fullName = profile.fullName

        // Assert
        XCTAssertEqual(profile.email, "")
        XCTAssertEqual(fullName, "Dimas Wisodewo")
        XCTAssertEqual(profile.avatarUrl?.absoluteString, "https://example.com/avatar.png")
    }

    func testFullNameUsesPlaceholderWhenBothNamesAreEmpty() {
        // Arrange
        let profile = ProfileEntity.fixture(firstName: "", lastName: "")

        // Act
        let fullName = profile.fullName

        // Assert
        XCTAssertEqual(fullName, "-")
    }
}

final class ProfileLocalDataSourceTests: XCTestCase {
    private let suiteName = "ProfileLocalDataSourceTests"

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSaveAndGetRoundTripsProfile() throws {
        // Arrange
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let dataSource = ProfileLocalDataSourceImpl(
            userDefaults: userDefaults,
            cacheKey: "profile"
        )
        let expectedProfile = ProfileEntity.fixture()

        // Act
        try dataSource.saveProfile(expectedProfile)
        let savedProfile = try dataSource.getSavedProfile()

        // Assert
        XCTAssertEqual(savedProfile, expectedProfile)
    }

    func testGetReturnsNilWhenCacheIsEmpty() throws {
        // Arrange
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let dataSource = ProfileLocalDataSourceImpl(userDefaults: userDefaults, cacheKey: "profile")

        // Act
        let savedProfile = try dataSource.getSavedProfile()

        // Assert
        XCTAssertNil(savedProfile)
    }
}

final class ProfileRepositoryTests: XCTestCase {
    func testGetProfileReturnsCacheWithoutFetchingRemote() async throws {
        // Arrange
        let cachedProfile = ProfileEntity.fixture()
        let localDataSource = ProfileLocalDataSourceSpy(savedProfile: cachedProfile)
        let remoteDataSource = ProfileRemoteDataSourceStub(result: .failure(TestError.expected))
        let repository = ProfileRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )

        // Act
        let profile = try await repository.getProfile()

        // Assert
        XCTAssertEqual(profile, cachedProfile)
        XCTAssertEqual(remoteDataSource.fetchCallCount, 0)
    }

    func testGetProfileFetchesAndCachesWhenLocalProfileIsMissing() async throws {
        // Arrange
        let remoteProfile = ProfileEntity.fixture()
        let localDataSource = ProfileLocalDataSourceSpy(savedProfile: nil)
        let remoteDataSource = ProfileRemoteDataSourceStub(result: .success(.fixture()))
        let repository = ProfileRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )

        // Act
        let profile = try await repository.getProfile()

        // Assert
        XCTAssertEqual(profile, remoteProfile)
        XCTAssertEqual(remoteDataSource.fetchCallCount, 1)
        XCTAssertEqual(localDataSource.savedProfiles, [remoteProfile])
    }

    func testFetchProfileReturnsRemoteProfileWhenSavingFails() async throws {
        // Arrange
        let localDataSource = ProfileLocalDataSourceSpy(saveError: TestError.expected)
        let remoteDataSource = ProfileRemoteDataSourceStub(result: .success(.fixture()))
        let repository = ProfileRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )

        // Act
        let profile = try await repository.fetchProfile()

        // Assert
        XCTAssertEqual(profile, .fixture())
        XCTAssertEqual(remoteDataSource.fetchCallCount, 1)
    }
}

final class GetProfileUseCaseTests: XCTestCase {
    func testExecuteUsesCacheByDefault() async throws {
        // Arrange
        let repository = ProfileRepositorySpy(
            cachedResult: .success(.fixture()),
            remoteResult: .failure(TestError.expected)
        )
        let useCase = GetProfileUseCase(repository: repository)

        // Act
        let profile = try await useCase.execute()

        // Assert
        XCTAssertEqual(profile, .fixture())
        XCTAssertEqual(repository.receivedCalls, [.getProfile])
    }

    func testExecuteFallsBackToRemoteWhenCacheFails() async throws {
        // Arrange
        let repository = ProfileRepositorySpy(
            cachedResult: .failure(TestError.expected),
            remoteResult: .success(.fixture())
        )
        let useCase = GetProfileUseCase(repository: repository)

        // Act
        let profile = try await useCase.execute()

        // Assert
        XCTAssertEqual(profile, .fixture())
        XCTAssertEqual(repository.receivedCalls, [.getProfile, .fetchProfile])
    }

    func testExecuteForceRefreshSkipsCache() async throws {
        // Arrange
        let repository = ProfileRepositorySpy(
            cachedResult: .success(.fixture(email: "cached@example.com")),
            remoteResult: .success(.fixture(email: "remote@example.com"))
        )
        let useCase = GetProfileUseCase(repository: repository)

        // Act
        let profile = try await useCase.execute(forceRefresh: true)

        // Assert
        XCTAssertEqual(profile.email, "remote@example.com")
        XCTAssertEqual(repository.receivedCalls, [.fetchProfile])
    }

    func testExecuteRejectsInvalidEmailFromRemote() async {
        // Arrange
        let repository = ProfileRepositorySpy(
            cachedResult: .failure(TestError.expected),
            remoteResult: .success(.fixture(email: "invalid-email"))
        )
        let useCase = GetProfileUseCase(repository: repository)

        // Act
        do {
            _ = try await useCase.execute(forceRefresh: true)
            XCTFail("Expected invalid email to throw")
        } catch {
            guard case ProfileDomainError.invalidEmail = error else {
                return XCTFail("Expected invalidEmail, received \(error)")
            }
        }

        // Assert
        XCTAssertEqual(repository.receivedCalls, [.fetchProfile])
    }
}

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testLoadProfileShowsProfileOnSuccess() async {
        // Arrange
        let useCase = ProfileUseCaseStub(result: .success(.fixture()))
        let viewModel = ProfileViewModel(getProfileUseCase: useCase, navigator: ProfileNavigatorSpy())

        // Act
        await viewModel.loadProfile()

        // Assert
        XCTAssertEqual(viewModel.state.data, .fixture())
        XCTAssertEqual(useCase.receivedForceRefreshValues, [false])
    }

    func testLoadProfilePreservesExistingProfileOnError() async {
        // Arrange
        let useCase = ProfileUseCaseStub(results: [.success(.fixture()), .failure(TestError.expected)])
        let viewModel = ProfileViewModel(getProfileUseCase: useCase, navigator: ProfileNavigatorSpy())

        // Act
        await viewModel.loadProfile()
        await viewModel.loadProfile(forceRefresh: true)

        // Assert
        XCTAssertEqual(viewModel.state.data, .fixture())
        XCTAssertNotNil(viewModel.state.error)
        XCTAssertEqual(useCase.receivedForceRefreshValues, [false, true])
    }

    func testDismissErrorRestoresPreviousProfile() async {
        // Arrange
        let useCase = ProfileUseCaseStub(results: [.success(.fixture()), .failure(TestError.expected)])
        let viewModel = ProfileViewModel(getProfileUseCase: useCase, navigator: ProfileNavigatorSpy())

        // Act
        await viewModel.loadProfile()
        await viewModel.loadProfile()
        viewModel.dismissError()

        // Assert
        XCTAssertEqual(viewModel.state.data, .fixture())
        XCTAssertNil(viewModel.state.error)
    }

    func testOpenSettingsNavigatesThroughNavigator() {
        // Arrange
        let navigator = ProfileNavigatorSpy()
        let viewModel = ProfileViewModel(
            getProfileUseCase: ProfileUseCaseStub(result: .success(.fixture())),
            navigator: navigator
        )

        // Act
        viewModel.openSettings()

        // Assert
        XCTAssertEqual(navigator.settingsNavigationCount, 1)
    }
}

private final class ProfileRepositorySpy: ProfileRepositoryProtocol {
    enum Call: Equatable { case getProfile; case fetchProfile }

    let cachedResult: Result<ProfileEntity, Error>
    let remoteResult: Result<ProfileEntity, Error>
    private(set) var receivedCalls: [Call] = []

    init(
        cachedResult: Result<ProfileEntity, Error>,
        remoteResult: Result<ProfileEntity, Error>
    ) {
        self.cachedResult = cachedResult
        self.remoteResult = remoteResult
    }

    func getProfile() async throws -> ProfileEntity {
        receivedCalls.append(.getProfile)
        return try cachedResult.get()
    }

    func fetchProfile() async throws -> ProfileEntity {
        receivedCalls.append(.fetchProfile)
        return try remoteResult.get()
    }
}

private final class ProfileLocalDataSourceSpy: ProfileLocalDataSourceProtocol {
    let savedProfile: ProfileEntity?
    let saveError: Error?
    private(set) var savedProfiles: [ProfileEntity] = []

    init(savedProfile: ProfileEntity? = nil, saveError: Error? = nil) {
        self.savedProfile = savedProfile
        self.saveError = saveError
    }

    func getSavedProfile() throws -> ProfileEntity? { savedProfile }

    func saveProfile(_ profile: ProfileEntity) throws {
        savedProfiles.append(profile)
        if let saveError { throw saveError }
    }
}

private final class ProfileRemoteDataSourceStub: ProfileRemoteDataSourceProtocol {
    let result: Result<ProfileDTO, Error>
    private(set) var fetchCallCount = 0

    init(result: Result<ProfileDTO, Error>) { self.result = result }

    func fetchProfile() async throws -> ProfileDTO {
        fetchCallCount += 1
        return try result.get()
    }
}

@MainActor
private final class ProfileUseCaseStub: GetProfileUseCaseProtocol {
    private var results: [Result<ProfileEntity, Error>]
    private(set) var receivedForceRefreshValues: [Bool] = []

    init(result: Result<ProfileEntity, Error>) { self.results = [result] }
    init(results: [Result<ProfileEntity, Error>]) { self.results = results }

    func execute(forceRefresh: Bool) async throws -> ProfileEntity {
        receivedForceRefreshValues.append(forceRefresh)
        guard !results.isEmpty else { throw TestError.expected }
        return try results.removeFirst().get()
    }
}

private final class ProfileNavigatorSpy: ProfileNavigator {
    private(set) var settingsNavigationCount = 0

    func navigateToSettings() { settingsNavigationCount += 1 }
    func dismiss(animated: Bool) {}
    func pop(animated: Bool) {}
}
