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
    private let navigationController = UINavigationController()
    private let container = DependencyContainer()
    
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
    
    func makeCoordinator() -> ProfileCoordinator {
        ProfileCoordinator(navigationController: navigationController, container: container)
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.start()
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
