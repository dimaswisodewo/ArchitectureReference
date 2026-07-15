//
//  ProfileNavigator.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import UIKit
import SwiftUI

protocol ProfileNavigator: AppNavigator {
    /// Navigates to the settings flow.
    func navigateToSettings()
}

final class ProfileCoordinator: Coordinator, ProfileNavigator {
    let navigationController: UINavigationController
    private let container: DependencyContainer
    
    init(navigationController: UINavigationController, container: DependencyContainer) {
        self.navigationController = navigationController
        self.container = container
    }
    
    func start() {
        // 1. Instantiate the assembly and register dependencies into the DI Container
        let assembly = ProfileAssembly(navigator: self)
        assembly.assemble(container: container)
        
        // 2. Resolve View Model and load screen
        do {
            let viewModel: ProfileViewModel = try container.resolve()
            let view = ProfileView(viewModel: viewModel)
            let hostingController = UIHostingController(rootView: view)
            
            // Set as root of this flow
            navigationController.setViewControllers([hostingController], animated: false)
        } catch {
            print("Coordinator Navigation Error: \(error.localizedDescription)")
        }
    }
    
    func navigateToSettings() {
        // Route destination stub
        let alert = UIAlertController(title: "Navigation Test", message: "Successfully navigated to Settings via Coordinator!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        navigationController.present(alert, animated: true)
    }
    
    func dismiss(animated: Bool) {
        navigationController.dismiss(animated: animated)
    }
    
    func pop(animated: Bool) {
        navigationController.popViewController(animated: animated)
    }
}
