//
//  AppNavigator.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import UIKit

/// Base interface for coordinator patterns managing app navigation.
protocol Coordinator: AnyObject {
    /// Starts the coordinator flow.
    func start()
}

/// Common navigation actions supported by feature navigators.
protocol AppNavigator: AnyObject {
    /// Dismisses a modally presented controller.
    func dismiss(animated: Bool)
    
    /// Pops the top view controller from the navigation stack.
    func pop(animated: Bool)
}

extension AppNavigator {
    // Default implementation can be empty or implemented on the concrete coordinator class
}
