import SwiftUI
import UIKit

protocol PokemonNavigator: AppNavigator {}

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

    func dismiss(animated: Bool) {
        navigationController.dismiss(animated: animated)
    }

    func pop(animated: Bool) {
        navigationController.popViewController(animated: animated)
    }
}
