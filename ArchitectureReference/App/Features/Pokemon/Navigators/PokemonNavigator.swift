import SwiftUI
import UIKit

protocol PokemonNavigator: AppNavigator {
    @MainActor
    func navigateToPokemonDetail(_ pokemon: PokemonEntity)
}

final class PokemonCoordinator: Coordinator, PokemonNavigator {
    let navigationController: UINavigationController
    private let container: DependencyContainer

    init(navigationController: UINavigationController, container: DependencyContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        PokemonAssembly(navigator: self).assemble(container: container)

        do {
            let viewModel: PokemonViewModel = try container.resolve()
            let hostingController = UIHostingController(rootView: PokemonView(viewModel: viewModel))
            navigationController.setViewControllers([hostingController], animated: false)
        } catch {
            assertionFailure("Pokémon coordinator failed to resolve dependencies: \(error)")
        }
    }

    @MainActor
    func navigateToPokemonDetail(_ pokemon: PokemonEntity) {
        do {
            let useCase: GetPokemonDetailUseCaseProtocol = try container.resolve()
            let viewModel = PokemonDetailViewModel(summary: pokemon, useCase: useCase)
            let viewController = UIHostingController(rootView: PokemonDetailView(viewModel: viewModel))
            navigationController.pushViewController(viewController, animated: true)
        } catch {
            assertionFailure("Pokémon detail failed to resolve dependencies: \(error)")
        }
    }

    func dismiss(animated: Bool) {
        navigationController.dismiss(animated: animated)
    }

    func pop(animated: Bool) {
        navigationController.popViewController(animated: animated)
    }
}
