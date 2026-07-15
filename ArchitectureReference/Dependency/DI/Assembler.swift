//
//  Assembler.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

/// Defines the contract for resolving dependencies with error propagation.
protocol Assembler {
    /// Resolves a registered type.
    /// - Throws: `DIError.missingDependency` if a factory is not found.
    /// - Returns: Concrete instance of the requested type.
    func resolve<T>() throws -> T
}

/// Defines the contract for modular registry assemblies.
protocol Assembly {
    /// Registers all dependencies associated with a specific module or component.
    /// - Parameter container: The mutable DI container.
    func assemble(container: DependencyContainer)
}

/// Feature specific dependency resolution errors.
enum DIError: LocalizedError {
    case missingDependency(String)
    
    var errorDescription: String? {
        switch self {
        case .missingDependency(let type):
            return "Dependency Injection Error: No factory registered for '\(type)'."
        }
    }
}

/// A lightweight, thread-safe, throwing native Swift Dependency Injection container.
/// Prevents crash-on-failure by propagating resolution errors.
final class DependencyContainer: Assembler {
    private var factories: [String: (Assembler) throws -> Any] = [:]
    private let lock = NSRecursiveLock()
    
    init() {}
    
    /// Registers a factory block for a specific type.
    /// - Parameters:
    ///   - serviceType: The interface or class type to register.
    ///   - factory: A block returning an instance of the registered type.
    func register<T>(_ serviceType: T.Type, factory: @escaping (Assembler) throws -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: serviceType)
        factories[key] = factory
    }
    
    /// Registers a weak reference to a class instance.
    /// This is useful for dependencies (like navigators/coordinators) whose lifecycle is managed
    /// externally, preventing retain cycles and deallocation issues in escaping registration closures.
    func registerWeak<T>(_ serviceType: T.Type, _ object: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: serviceType)
        weak var weakObject = object
        factories[key] = { _ in
            guard let resolvedInstance = weakObject as? T else {
                throw DIError.missingDependency("Weak dependency of type '\(key)' was deallocated or type cast failed.")
            }
            return resolvedInstance
        }
    }
    
    /// Resolves a registered interface to its concrete implementation.
    /// Throws a `DIError` if the registry is missing.
    /// - Throws: `DIError` on missing dependency.
    /// - Returns: Resolved instance of the requested type.
    func resolve<T>() throws -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: T.self)
        guard let factory = factories[key] else {
            throw DIError.missingDependency(key)
        }
        
        guard let resolvedInstance = try factory(self) as? T else {
            throw DIError.missingDependency("Type casting mismatch for \(key)")
        }
        
        return resolvedInstance
    }
}
