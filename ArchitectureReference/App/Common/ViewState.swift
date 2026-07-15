//
//  ViewState.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

/// Represents the state of data within a view.
enum ViewState<T> {
    /// Initial idle state before any action is performed.
    case idle
    
    /// Data is loading. Can optionally hold previous data to avoid flickering or blank states during reload.
    case loading(previousData: T? = nil)
    
    /// Data loaded successfully.
    case success(T)
    
    /// An error occurred. Can optionally hold previous data to keep showing cache during errors.
    case failure(Error, previousData: T? = nil)
}

extension ViewState {
    /// Returns true if currently in the loading state.
    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }
    
    /// Safely accesses any payload/data present in success, loading, or failure states.
    var data: T? {
        switch self {
        case .success(let data):
            return data
        case .loading(let previousData):
            return previousData
        case .failure(_, let previousData):
            return previousData
        default:
            return nil
        }
    }
    
    /// Accesses the error if present.
    var error: Error? {
        switch self {
        case .failure(let error, _):
            return error
        default:
            return nil
        }
    }
    
    /// Helper to get the localized description of the error.
    var errorMessage: String? {
        error?.localizedDescription
    }
}

// Enable comparison of ViewStates when the generic type itself is Equatable
extension ViewState: Equatable where T: Equatable {
    static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading(let lhsData), .loading(let rhsData)):
            return lhsData == rhsData
        case (.success(let lhsData), .success(let rhsData)):
            return lhsData == rhsData
        case (.failure(let lhsError, let lhsData), .failure(let rhsError, let rhsData)):
            return lhsError.localizedDescription == rhsError.localizedDescription && lhsData == rhsData
        default:
            return false
        }
    }
}
