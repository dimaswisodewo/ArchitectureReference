//
//  ArchitectureReferenceApp.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import SwiftUI
import UIKit

@main
struct ArchitectureReferenceApp: App {
    private let navigationController: UINavigationController
    private let container: DependencyContainer

    init() {
        let container = DependencyContainer()
        Self.setupDependencies(in: container)

        self.container = container
        self.navigationController = UINavigationController()
    }

    /// Application composition root. Core dependencies are ready before any
    /// coordinator registers and resolves its feature-specific graph.
    static func setupDependencies(in container: DependencyContainer) {
        CoreAssembly().assemble(container: container)
    }
    
    var body: some Scene {
        WindowGroup {
            CoordinatorView(navigationController: navigationController, container: container)
                .ignoresSafeArea()
        }
    }
}

/// A SwiftUI wrapper that bridges the UIKit navigation flow to SwiftUI lifecycle
struct CoordinatorView: UIViewControllerRepresentable {
    let navigationController: UINavigationController
    let container: DependencyContainer
    
    func makeCoordinator() -> PokemonCoordinator {
        PokemonCoordinator(navigationController: navigationController, container: container)
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.start()
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
