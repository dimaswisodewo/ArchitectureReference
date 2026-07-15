//
//  GetProfileUseCase.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

final class GetProfileUseCase {
    private let repository: ProfileRepositoryProtocol
    
    init(repository: ProfileRepositoryProtocol) {
        self.repository = repository
    }
    
    /// Executes the business logic to get the profile.
    /// Supports force-refreshing from the network client or attempting local cache first.
    func execute(forceRefresh: Bool = false) async throws -> ProfileEntity {
        if forceRefresh {
            let profile = try await repository.fetchProfile()
            try validate(profile)
            return profile
        } else {
            do {
                let profile = try await repository.getProfile()
                try validate(profile)
                return profile
            } catch {
                // Cache miss or local error -> fallback to remote fetch
                let profile = try await repository.fetchProfile()
                try validate(profile)
                return profile
            }
        }
    }
    
    private func validate(_ profile: ProfileEntity) throws {
        // Enforce business validation: e.g. email validity check
        guard profile.email.contains("@") else {
            throw ProfileDomainError.invalidEmail
        }
    }
}

enum ProfileDomainError: LocalizedError {
    case invalidEmail
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "The user's profile has an invalid email address."
        }
    }
}
