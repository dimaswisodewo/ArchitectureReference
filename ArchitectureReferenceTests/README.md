# ArchitectureReference XCTest Guide

This directory contains the unit tests for the `ArchitectureReference` iOS app. The suite uses XCTest to verify business rules, data transformations, persistence behavior, networking contracts, dependency registration, and view-model state transitions without relying on live services.

The suite currently contains 38 tests organized by behavior:

| Test area | What it verifies |
| --- | --- |
| Pokémon | DTO mapping, use-case validation, repository pagination/fallback, list and detail view models |
| Profile | DTO/entity mapping, isolated cache behavior, repository orchestration, validation, view-model states |
| Infrastructure | `ViewState`, dependency injection, endpoint definitions, URLSession requests and HTTP errors |
| Shared support | Fixtures and small typed stubs/spies used by multiple suites |

## Why unit tests exist

A unit test checks one small behavior in isolation. It should answer a simple question such as:

> When loading a valid Pokémon page succeeds, does the view model expose the returned Pokémon?

The test should not need a real API, a particular cache state, a running coordinator, or a specific test order to answer that question. Isolation makes failures local and repeatable. Repeatability makes tests useful as a safety net during refactoring.

Unit tests are different from integration and UI tests:

- **Unit tests** exercise one type and controlled collaborators quickly.
- **Integration tests** verify that real components work together, such as a repository with a real database.
- **UI tests** launch the app and verify user-visible flows through the interface.

This target focuses on unit tests. It deliberately does not test SwiftUI rendering or automate the full app flow.

## The system under test

The system under test is the production type whose behavior a test is examining. Some teams call its variable `sut` (“system under test”). This project uses descriptive names instead:

```swift
let repository = PokemonRepositoryImpl(remoteDataSource: remoteDataSource)
let page = try await repository.fetchPokemonPage(limit: 20, offset: 0)
```

`repository` is slightly longer than `sut`, but a reader can understand the test without translating an abbreviation. Use one primary production type per test class and name the test class after it, such as `PokemonRepositoryTests` or `ProfileViewModelTests`.

## Arrange, Act, Assert

Every test explicitly labels its three phases with comments so a reader can scan the flow immediately:

1. `// Arrange`: configure inputs and collaborators.
2. `// Act`: perform one operation.
3. `// Assert`: verify the observable result and, when relevant, collaborator calls.

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

Keep the important input values in the test. Extract only noisy construction into a fixture or an explicitly named factory such as `makeViewModel()`. A little visible duplication is preferable to a helper that hides the behavior being tested.

## Naming tests

Use concise, outcome-focused names:

```swift
testLoadInitialPageShowsPokemonOnSuccess
testPaginationKeepsExistingPokemonOnError
testExecuteRejectsInvalidPagination
```

The name should describe the observable behavior, not the implementation steps. Avoid names such as `test1`, `testExecute`, or names that only repeat the production method without explaining the expected result.

## Test doubles

The production code depends on protocols so tests can replace external behavior with small, predictable objects.

- **Stub:** returns a configured value or error.
- **Spy:** records calls so the test can verify collaboration.
- **Fake:** provides a small working implementation, such as an in-memory cache.

Prefer typed doubles with domain-readable properties:

```swift
private(set) var receivedPageRequests: [PageRequest] = []
private(set) var fetchCallCount = 0
private(set) var selectedPokemon: PokemonEntity?
```

Avoid a generic mock that stores calls as strings or `[Any]`. Typed doubles make incorrect calls fail at compile time and make assertions self-explanatory.

## Fixtures

Fixtures provide useful defaults while allowing a test to override only the value relevant to its behavior:

```swift
let invalidProfile = ProfileEntity.fixture(email: "invalid-email")
```

The shared fixtures in `TestSupport.swift` create valid domain models, DTOs, sprites, and profiles. Raw JSON remains in tests that specifically verify decoding; other tests construct models directly so they stay focused on their own layer.

## Testing errors and boundaries

Good unit suites include more than the happy path:

- Valid input delegates and returns the expected result.
- Invalid pagination or identifiers are rejected before a repository call.
- Repository failures preserve usable existing data when that is the contract.
- Cache misses fall back to remote loading.
- Invalid domain data produces a domain error.
- View-model guards prevent duplicate or unnecessary work.

Error tests should assert the meaningful error case and, when applicable, that the collaborator was not called.

## Async and MainActor tests

Async production methods are tested with `async` XCTest methods and direct `await` calls. Do not use arbitrary sleeps to guess when work has finished.

View models are `@MainActor`, so their test classes are also marked `@MainActor`:

```swift
@MainActor
final class PokemonViewModelTests: XCTestCase {
    func testLoadInitialPageShowsPokemonOnSuccess() async {
        let useCase = PokemonUseCaseStub(results: [
            .success(PokemonPage(pokemon: [.fixture()], nextOffset: nil))
        ])
        let viewModel = PokemonViewModel(getPokemonUseCase: useCase)

        await viewModel.loadInitialPage()

        XCTAssertEqual(viewModel.state.data?.count, 1)
    }
}
```

For an in-flight or re-entrancy test, use a continuation-backed stub that the test controls. Do not use timing assumptions.

## Isolating external dependencies

Tests must not depend on production global state:

- `URLSessionNetworkClient` accepts an injected `URLSession`.
- Networking tests use an ephemeral session and a test `URLProtocol`.
- `ProfileLocalDataSourceImpl` accepts an injected `UserDefaults` suite and cache key.
- Profile’s production fallback delay is configurable so tests do not wait one second.
- The hosted XCTest app renders `EmptyView` instead of starting the live coordinator and Pokémon request flow.

These are behavior-preserving seams. Production defaults remain `.shared`, `.standard`, the normal cache key, and the normal fallback delay.

## Running the tests

Use the full Xcode developer tools when the shell is configured for Command Line Tools:

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

Discover a destination with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun simctl list devices available
```

Use focused execution while iterating:

```sh
xcodebuild test \
  -project ArchitectureReference.xcodeproj \
  -scheme ArchitectureReference \
  -only-testing:ArchitectureReferenceTests/PokemonViewModelTests
```

Inspect the generated result bundle with `xccov`:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun xccov view --report --only-targets /path/to/Test.xcresult
```

Coverage is evidence, not the sole quality metric. Generated SwiftUI code can lower an app-wide percentage while domain and view-model behavior are well covered. Prefer meaningful behavior coverage and readable tests over a forced global threshold.

## Troubleshooting

- **`xcodebuild` requires Xcode:** set `DEVELOPER_DIR` to the Xcode developer directory.
- **No simulator destination:** run `simctl list devices available` and choose an installed, booted iOS simulator.
- **A test unexpectedly makes a network request:** check that the test uses a stub or injected URLSession and that app bootstrap is not starting the coordinator.
- **A cache test is flaky:** use a unique `UserDefaults(suiteName:)` and clear its domain in `tearDown`.
- **An async test is intermittent:** remove sleeps and use direct `await` or a controlled continuation.
- **A test has too many assertions:** split unrelated outcomes into separate tests.

For the complete implementation sequence, read [IMPLEMENTATION_STEPS.md](IMPLEMENTATION_STEPS.md).

For reusable guidance across projects, see the personal [XCTest Unit Testing skill](/Users/mdimaswisodewo/.codex/skills/xctest-unit-testing/SKILL.md).
