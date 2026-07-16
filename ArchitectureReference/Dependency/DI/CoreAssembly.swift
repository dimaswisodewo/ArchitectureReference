import Foundation

/// Registers application-wide infrastructure before any feature flow starts.
final class CoreAssembly: Assembly {
    func assemble(container: DependencyContainer) {
        let networkClient = URLSessionNetworkClient()
        container.registerInstance(NetworkClient.self, instance: networkClient)
    }
}
