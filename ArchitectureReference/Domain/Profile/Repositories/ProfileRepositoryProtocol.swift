//
//  ProfileRepositoryProtocol.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

protocol ProfileRepositoryProtocol {
    /// Retrieve the cached profile
    func getProfile() async throws -> ProfileEntity
    
    /// Fetch the profile from remote and refresh the cache
    func fetchProfile() async throws -> ProfileEntity
}
