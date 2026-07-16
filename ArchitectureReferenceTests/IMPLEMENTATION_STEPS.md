# Implementing the XCTest Suite Step by Step

This guide explains how the current `ArchitectureReferenceTests` target was designed and implemented. Follow the steps in order when adding tests to another feature or extending this project.

## Step 1: Read the production behavior first

Start with the production type under test and trace its collaborators inward and outward:

```text
View -> ViewModel -> Use Case -> Repository Protocol -> Data Source
```

Record inputs, default values, success outputs, published state, errors, guard clauses, and side effects such as navigation, cache writes, or network requests. Do not begin by copying an existing test; first identify the behavior contract.

## Step 2: Establish a baseline

Run the existing suite before editing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project ArchitectureReference.xcodeproj \
  -scheme ArchitectureReference \
  -destination 'platform=iOS Simulator,id=<device-id>' \
  -derivedDataPath /tmp/ArchitectureReferenceBaseline \
  CODE_SIGNING_ALLOWED=NO
```

Record passing tests, failures, warnings, hosted-app side effects, and baseline coverage. The original suite passed 8 tests; the completed suite passes 38.

## Step 3: Select one system under test per suite

Create one XCTest class for each meaningful production type:

```swift
final class GetPokemonUseCaseTests: XCTestCase { }
final class PokemonRepositoryTests: XCTestCase { }
@MainActor final class PokemonViewModelTests: XCTestCase { }
```

Use explicit local names such as `useCase`, `repository`, and `viewModel`. Do not make `sut` a required convention; readable names matter more than abbreviation.

## Step 4: Identify dependency seams

If a test requires a live service or global state, introduce the smallest behavior-preserving seam:

- Depend on a protocol when a concrete use case must be replaced.
- Inject `URLSession` when request construction or HTTP behavior must be tested.
- Inject `UserDefaults` and a cache key when persistence must be isolated.
- Inject a delay or clock when production timing would slow or destabilize tests.
- Prevent hosted test application startup from launching unrelated coordinators or network work.

Keep production defaults unchanged. The seam should make testing possible, not redesign the feature.

## Step 5: Build typed fixtures

Add meaningful defaults in shared test support:

```swift
extension PokemonEntity {
    static func fixture(id: Int = 1, name: String = "bulbasaur") -> PokemonEntity {
        PokemonEntity(id: id, name: name, artworkURL: nil)
    }
}
```

Use fixtures for ordinary model construction. Keep JSON literals only in decoding tests, where the encoded shape is the behavior being verified.

## Step 6: Build typed stubs and spies

Choose the smallest double that expresses the test:

- Use a stub when only a return value or error matters.
- Use a spy when the test must verify calls or arguments.
- Use a fake for a simple in-memory implementation.

Prefer readable recorded properties:

```swift
private(set) var receivedPageRequests: [PageRequest] = []
private(set) var fetchCallCount = 0
```

For sequential async responses, use a clearly named response queue and fail explicitly when it is exhausted. Do not create a generic invocation framework.

## Step 7: Write the first success test

Make the happy path establish the suite’s style:

```swift
func testExecuteForwardsValidPaginationToRepository() async throws {
    let expectedPage = PokemonPage(pokemon: [.fixture()], nextOffset: 20)
    let repository = PokemonRepositorySpy(pageResult: .success(expectedPage))
    let useCase = GetPokemonUseCase(repository: repository)

    let page = try await useCase.execute(limit: 20, offset: 40)

    XCTAssertEqual(page, expectedPage)
    XCTAssertEqual(repository.receivedPageRequests, [.init(limit: 20, offset: 40)])
}
```

The test has visible Arrange, Act, and Assert phases. Its name describes the result, and the assertions check both output and delegation because both are part of the use-case contract.

## Step 8: Add failure and boundary tests

For every behavior-heavy type, add the cases that can change control flow:

- Invalid pagination and identifiers are rejected before repository calls.
- Repository errors preserve existing data when required.
- Cache misses fetch remotely and save the result.
- Invalid emails produce `ProfileDomainError.invalidEmail`.
- HTTP non-2xx responses become errors.
- Empty or missing data follows the documented fallback behavior.

Assert the error case explicitly. Also assert suppressed collaborator calls when the guard itself is the behavior.

## Step 9: Test view models on their actor

Mark suites for `@MainActor` view models with `@MainActor` and await their methods directly:

```swift
@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testLoadProfilePreservesExistingProfileOnError() async {
        let useCase = ProfileUseCaseStub(results: [
            .success(.fixture()),
            .failure(TestError.expected)
        ])
        let viewModel = ProfileViewModel(
            getProfileUseCase: useCase,
            navigator: ProfileNavigatorSpy()
        )

        await viewModel.loadProfile()
        await viewModel.loadProfile(forceRefresh: true)

        XCTAssertEqual(viewModel.state.data, .fixture())
        XCTAssertNotNil(viewModel.state.error)
    }
}
```

Do not use sleeps to observe a state change. If a guard depends on work remaining in flight, use a continuation-backed stub controlled by the test and resume it during cleanup.

## Step 10: Isolate networking

Inject an ephemeral `URLSession` whose `protocolClasses` contains a test `URLProtocol`:

```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [URLProtocolStub.self]
let session = URLSession(configuration: configuration)
let networkClient = URLSessionNetworkClient(session: session)
```

Use the protocol stub to record the outgoing request, return controlled data, and produce a chosen HTTP status or transport error. Reset static handlers in `tearDown`.

Keep request construction and response decoding assertions separate when combining them makes a test difficult to scan.

## Step 11: Isolate persistence

Create a unique suite and inject it into the local data source:

```swift
let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "ProfileLocalDataSourceTests"))
let dataSource = ProfileLocalDataSourceImpl(
    userDefaults: userDefaults,
    cacheKey: "profile"
)
```

Clear the suite’s persistent domain in `tearDown`. Never let one test depend on data written by another test or on `UserDefaults.standard`.

## Step 12: Add infrastructure tests last

Once feature behavior is covered, verify the boundaries that make composition work:

- `ViewState` data and error accessors.
- DI instance scope and missing dependency errors.
- Endpoint paths, methods, headers, and parameters.
- URLSession query parameters, JSON bodies, decoding, and HTTP failures.

These tests should remain small. They protect contracts, not implementation details.

## Step 13: Attach files to the Xcode target

When adding Swift files to a manually managed `.xcodeproj`, ensure each file has a `PBXFileReference`, a `PBXBuildFile`, membership in the `ArchitectureReferenceTests` group, and membership in the test target’s `PBXSourcesBuildPhase`. A file existing on disk is not enough; Xcode must compile it as part of the test target.

## Step 14: Iterate with focused tests

Run the smallest relevant suite while editing:

```sh
xcodebuild test \
  -project ArchitectureReference.xcodeproj \
  -scheme ArchitectureReference \
  -only-testing:ArchitectureReferenceTests/ProfileViewModelTests
```

Fix compilation and assertion failures immediately. Keep each test readable while its context is fresh instead of postponing cleanup until the entire suite is complete.

## Step 15: Run and inspect the full suite

Run all tests with temporary DerivedData, code signing disabled, and coverage enabled:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project ArchitectureReference.xcodeproj \
  -scheme ArchitectureReference \
  -destination 'platform=iOS Simulator,id=<device-id>' \
  -derivedDataPath /tmp/ArchitectureReferenceDerivedData \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO
```

Then inspect the result bundle:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun xccov view --report --only-targets /path/to/Test.xcresult
```

Confirm all tests pass repeatedly, no unrelated live network requests occur, no test depends on shared persistence or order, and critical domain/data/view-model paths are covered.

## Step 16: Apply the readability checklist

Before considering the suite complete, review every test:

- Can a reader identify the production type immediately?
- Does the test name describe the outcome?
- Are Arrange, Act, and Assert visually distinct?
- Are important values visible without opening multiple helpers?
- Does each double have a clear purpose?
- Is there one coherent behavior per test?
- Would the test fail for the right reason if the behavior regressed?

If the answer is no, simplify the test before adding more coverage.
