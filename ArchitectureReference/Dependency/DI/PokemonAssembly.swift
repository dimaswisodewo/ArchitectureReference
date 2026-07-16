import Foundation

final class PokemonAssembly: Assembly {
    private weak var navigator: PokemonNavigator?

    init(navigator: PokemonNavigator) {
        self.navigator = navigator
    }

    func assemble(container: DependencyContainer) {
        if let navigator {
            container.registerWeak(PokemonNavigator.self, navigator)
        }

        container.register(PokemonRemoteDataSourceProtocol.self) { resolver in
            try PokemonRemoteDataSourceImpl(networkClient: resolver.resolve())
        }
        
        container.register(PokemonRepositoryProtocol.self) { resolver in
            try PokemonRepositoryImpl(remoteDataSource: resolver.resolve())
        }
        
        container.register(GetPokemonUseCaseProtocol.self) { resolver in
            try GetPokemonUseCase(repository: resolver.resolve())
        }
        container.register(GetPokemonDetailUseCaseProtocol.self) { resolver in
            try GetPokemonDetailUseCase(repository: resolver.resolve())
        }
        
        container.register(PokemonViewModel.self) { resolver in
            try MainActor.assumeIsolated {
                let navigator: PokemonNavigator = try resolver.resolve()
                return try PokemonViewModel(
                    getPokemonUseCase: resolver.resolve(),
                    navigator: navigator
                )
            }
        }
    }
}
