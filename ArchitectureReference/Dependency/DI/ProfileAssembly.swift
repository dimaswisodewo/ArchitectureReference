//
//  ProfileAssembly.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

final class ProfileAssembly: Assembly {
    private weak var navigator: ProfileNavigator?
    
    init(navigator: ProfileNavigator) {
        self.navigator = navigator
    }
    
    func assemble(container: DependencyContainer) {
        // 1. Register Feature Navigator (Weak reference prevents retain cycle)
        if let navigator = navigator {
            container.registerWeak(ProfileNavigator.self, navigator)
        }
        
        // 2. Register Data Sources. Core dependencies are registered by the app.
        container.register(ProfileRemoteDataSourceProtocol.self) { resolver in
            try ProfileRemoteDataSourceImpl(networkClient: resolver.resolve())
        }
        
        container.register(ProfileLocalDataSourceProtocol.self) { _ in
            ProfileLocalDataSourceImpl()
        }
        
        // 3. Register Repository Interface
        container.register(ProfileRepositoryProtocol.self) { resolver in
            try ProfileRepositoryImpl(
                remoteDataSource: resolver.resolve(),
                localDataSource: resolver.resolve()
            )
        }
        
        // 4. Register Use Case Interactor
        container.register(GetProfileUseCase.self) { resolver in
            try GetProfileUseCase(repository: resolver.resolve())
        }
        
        // 5. Register ViewModel (Runs on @MainActor, using Swift 6 compile-safe assumeIsolated block)
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
