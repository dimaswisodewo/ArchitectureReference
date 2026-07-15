# Step-by-Step Developer Implementation Guide
*Created by Meynabel Dimas Wisodewo*

This guide walks a developer through creating a brand-new feature from scratch using the Clean Architecture pattern implemented in this project. We will use the **Profile** feature as our concrete reference.

---

## Architecture Flow Recap

```
[ Domain Entity ] ────> [ Repo Protocol ] ────> [ GetProfileUseCase ]
                                                      │
                                                      ▼
[ ProfileDTO ] ───────────────────────────> [ ProfileRepositoryImpl ]
                                                      │
                                                      ▼
[ ProfileAssembly ] ──────────────────────> [ ProfileViewModel ] ──> [ ProfileView (SwiftUI) ]
```

---

## Step 1: Implement the Domain Layer (Pure Swift)

Create these files inside `Domain/Profile/`.

### 1.1 Create the Entity (`Domain/Profile/Entities/ProfileEntity.swift`)
Define the immutable data structure representing the user's profile. No external frameworks should be imported here.
```swift
import Foundation

struct ProfileEntity: Identifiable, Equatable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let address: String
    let birthDate: String
    let position: String
    let avatarUrl: URL?
    
    // Business computed property
    var fullName: String {
        if firstName.isEmpty && lastName.isEmpty {
            return "-"
        }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

### 1.2 Create the Repository Protocol (`Domain/Profile/Repositories/ProfileRepositoryProtocol.swift`)
Declare the operations contract required by the business logic. The Data layer will implement this protocol.
```swift
import Foundation

protocol ProfileRepositoryProtocol {
    func getProfile() async throws -> ProfileEntity
    func fetchProfile() async throws -> ProfileEntity
}
```

### 1.3 Create the Use Case (`Domain/Profile/UseCases/GetProfileUseCase.swift`)
Implement the business rules (such as email validation or processing).
```swift
import Foundation

final class GetProfileUseCase {
    private let repository: ProfileRepositoryProtocol
    
    init(repository: ProfileRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(forceRefresh: Bool = false) async throws -> ProfileEntity {
        let profile = forceRefresh 
            ? try await repository.fetchProfile() 
            : try await repository.getProfile()
            
        // Enforce business validation
        guard profile.email.contains("@") else {
            throw ProfileDomainError.invalidEmail
        }
        
        return profile
    }
}

enum ProfileDomainError: LocalizedError {
    case invalidEmail
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "The user's profile has an invalid email address."
        }
    }
}
```

---

## Step 2: Implement the Data Layer (API & Local Storage)

Create these files inside `Data/Profile/`.

### 2.1 Create the API Endpoint (`Data/Profile/DataSources/ProfileRemoteDataSource.swift` - Part 1)
Conform to `APIEndpoint` to declare routing details, headers, and HTTP methods.
```swift
import Foundation

enum ProfileEndpoint: APIEndpoint {
    case getProfile
    
    var baseURL: URL {
        return URL(string: "https://api.tbig-mobile.com")!
    }
    
    var path: String {
        return "/api/v1/profile"
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var headers: [String : String]? {
        return ["Authorization": "Bearer sample_token"]
    }
    
    var task: HTTPTask {
        return .requestPlain
    }
}
```

### 2.2 Create the DTO (`Data/Profile/Models/ProfileDTO.swift`)
Represent the JSON response structures. Implement `.toDomain()` mapping to convert DTOs into pure Domain entities.
```swift
import Foundation

struct ProfileResponseDTO: Codable {
    let meta: ResponseMetaDTO
    let data: ProfileDTO?
}

struct ResponseMetaDTO: Codable {
    let error: Bool
    let code: Int
    let message: String
}

struct ProfileDTO: Codable {
    let id: Int
    let userid: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let phoneNumber: String?
    let address: String?
    let birthDate: String?
    let position: String?
    let avatar: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userid
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case phoneNumber = "phone_number"
        case address
        case birthDate = "birth_date"
        case position
        case avatar
    }
    
    func toDomain() -> ProfileEntity {
        return ProfileEntity(
            id: String(id),
            email: email ?? "",
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            phoneNumber: phoneNumber ?? "",
            address: address ?? "",
            birthDate: birthDate ?? "",
            position: position ?? "",
            avatarUrl: avatar.flatMap { URL(string: $0) }
        )
    }
}
```

### 2.3 Create the Remote & Local Data Sources

#### Remote Source: (`Data/Profile/DataSources/ProfileRemoteDataSource.swift` - Part 2)
Handles network interaction using `NetworkClient`.
```swift
protocol ProfileRemoteDataSourceProtocol {
    func fetchProfile() async throws -> ProfileDTO
}

final class ProfileRemoteDataSourceImpl: ProfileRemoteDataSourceProtocol {
    private let networkClient: NetworkClient
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
    
    func fetchProfile() async throws -> ProfileDTO {
        let response: ProfileResponseDTO = try await networkClient.request(ProfileEndpoint.getProfile)
        guard let data = response.data else {
            throw NSError(domain: "Network", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data found"])
        }
        return data
    }
}
```

#### Local Storage: (`Data/Profile/DataSources/ProfileLocalDataSource.swift`)
Handles cache read/writes. Concurrency boundaries apply: Realm/caching objects should never traverse threads. Convert them to domain entities before returning.
```swift
protocol ProfileLocalDataSourceProtocol {
    func getSavedProfile() throws -> ProfileEntity?
    func saveProfile(_ profile: ProfileEntity) throws
}

final class ProfileLocalDataSourceImpl: ProfileLocalDataSourceProtocol {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "com.architecturereference.cache.profile"
    
    func getSavedProfile() throws -> ProfileEntity? {
        guard let dict = userDefaults.dictionary(forKey: cacheKey) else { return nil }
        // Map dictionary keys to return a ProfileEntity
        return ProfileEntity(
            id: dict["id"] as? String ?? "",
            email: dict["email"] as? String ?? "",
            // ...
            avatarUrl: (dict["avatarUrl"] as? String).flatMap { URL(string: $0) }
        )
    }
    
    func saveProfile(_ profile: ProfileEntity) throws {
        let dict: [String: Any] = [
            "id": profile.id,
            "email": profile.email,
            // ...
            "avatarUrl": profile.avatarUrl?.absoluteString ?? ""
        ]
        userDefaults.set(dict, forKey: cacheKey)
    }
}
```

### 2.4 Create the Repository Implementation (`Data/Profile/Repositories/ProfileRepositoryImpl.swift`)
Orchestrates remote fetch, disk-caching, and offline fallbacks.
```swift
final class ProfileRepositoryImpl: ProfileRepositoryProtocol {
    private let remoteDataSource: ProfileRemoteDataSourceProtocol
    private let localDataSource: ProfileLocalDataSourceProtocol
    
    init(remoteDataSource: ProfileRemoteDataSourceProtocol, localDataSource: ProfileLocalDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }
    
    func getProfile() async throws -> ProfileEntity {
        if let cached = try localDataSource.getSavedProfile() {
            return cached
        }
        return try await fetchProfile()
    }
    
    func fetchProfile() async throws -> ProfileEntity {
        let dto = try await remoteDataSource.fetchProfile()
        let entity = dto.toDomain()
        try? localDataSource.saveProfile(entity)
        return entity
    }
}
```

---

## Step 3: Implement the App/Presentation Layer

Create these files inside `App/Features/Profile/`.

### 3.1 Create the Navigator Protocol & Coordinator
Coordinates navigation transitions and module assemblies.

#### Protocol: (`App/Features/Profile/Navigators/ProfileNavigator.swift` - Part 1)
```swift
protocol ProfileNavigator: AppNavigator {
    func navigateToSettings()
}
```

#### Coordinator: (`App/Features/Profile/Navigators/ProfileNavigator.swift` - Part 2)
```swift
import UIKit
import SwiftUI

final class ProfileCoordinator: Coordinator, ProfileNavigator {
    let navigationController: UINavigationController
    private let container: DependencyContainer
    
    init(navigationController: UINavigationController, container: DependencyContainer) {
        self.navigationController = navigationController
        self.container = container
    }
    
    func start() {
        let assembly = ProfileAssembly(navigator: self)
        assembly.assemble(container: container)
        
        do {
            let viewModel: ProfileViewModel = try container.resolve()
            let view = ProfileView(viewModel: viewModel)
            let hostingController = UIHostingController(rootView: view)
            navigationController.setViewControllers([hostingController], animated: true)
        } catch {
            print("Failed to route to Profile: \(error.localizedDescription)")
        }
    }
    
    func navigateToSettings() {
        // Push settings screen or present modal details
    }
    
    func dismiss(animated: Bool) { navigationController.dismiss(animated: animated) }
    func pop(animated: Bool) { navigationController.popViewController(animated: animated) }
}
```

### 3.2 Create the ViewModel (`App/Features/Profile/ViewModel/ProfileViewModel.swift`)
Must be marked `@MainActor` to bind safely to the UI thread.
```swift
import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: ProfileEntity?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let getProfileUseCase: GetProfileUseCase
    private weak var navigator: ProfileNavigator?
    
    init(getProfileUseCase: GetProfileUseCase, navigator: ProfileNavigator) {
        self.getProfileUseCase = getProfileUseCase
        self.navigator = navigator
    }
    
    func loadProfile(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await getProfileUseCase.execute(forceRefresh: forceRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func openSettings() {
        navigator?.navigateToSettings()
    }
}
```

### 3.3 Create the SwiftUI View (`App/Features/Profile/Views/ProfileView.swift`)
```swift
import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
            } else if let profile = viewModel.profile {
                Text(profile.fullName)
                    .font(.title)
                Text(profile.email)
                    .foregroundColor(.secondary)
                
                Button("Settings") {
                    viewModel.openSettings()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("No Profile Synchronized")
            }
        }
        .task {
            await viewModel.loadProfile()
        }
        .alert(item: Binding<AlertError?>(
            get: { viewModel.errorMessage.map { AlertError(message: $0) } },
            set: { _ in viewModel.errorMessage = nil }
        )) { error in
            Alert(title: Text("Error"), message: Text(error.message))
        }
    }
}
```

---

## Step 4: Wire Dependencies & Register Assembly

Create inside `Dependency/DI/`.

### 4.1 Create the Module Assembly (`Dependency/DI/ProfileAssembly.swift`)
Wire up data sources, repositories, use cases, and view models. Wrap the view model initialization in a `MainActor.assumeIsolated` block.
```swift
import Foundation

final class ProfileAssembly: Assembly {
    private weak var navigator: ProfileNavigator?
    
    init(navigator: ProfileNavigator) {
        self.navigator = navigator
    }
    
    func assemble(container: DependencyContainer) {
        if let navigator = navigator {
            container.registerWeak(ProfileNavigator.self, navigator)
        }
        
        container.register(NetworkClient.self) { _ in
            URLSessionNetworkClient()
        }
        
        container.register(ProfileRemoteDataSourceProtocol.self) { resolver in
            try ProfileRemoteDataSourceImpl(networkClient: resolver.resolve())
        }
        
        container.register(ProfileLocalDataSourceProtocol.self) { _ in
            ProfileLocalDataSourceImpl()
        }
        
        container.register(ProfileRepositoryProtocol.self) { resolver in
            try ProfileRepositoryImpl(
                remoteDataSource: resolver.resolve(),
                localDataSource: resolver.resolve()
            )
        }
        
        container.register(GetProfileUseCase.self) { resolver in
            try GetProfileUseCase(repository: resolver.resolve())
        }
        
        container.register(ProfileViewModel.self) { resolver in
            return try MainActor.assumeIsolated {
                try ProfileViewModel(
                    getProfileUseCase: resolver.resolve(),
                    navigator: resolver.resolve()
                )
            }
        }
    }
}
```
