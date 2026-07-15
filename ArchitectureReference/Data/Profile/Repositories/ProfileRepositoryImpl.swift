//
//  ProfileRepositoryImpl.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

final class ProfileRepositoryImpl: ProfileRepositoryProtocol {
    private let remoteDataSource: ProfileRemoteDataSourceProtocol
    private let localDataSource: ProfileLocalDataSourceProtocol
    
    init(
        remoteDataSource: ProfileRemoteDataSourceProtocol,
        localDataSource: ProfileLocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }
    
    /// Retrieves the profile. Looks in the local cache first; falls back to network on miss.
    func getProfile() async throws -> ProfileEntity {
        if let cached = try localDataSource.getSavedProfile() {
            print("Repository: Returning locally cached profile data.")
            return cached
        }
        print("Repository: Local cache miss. Fetching from remote source.")
        return try await fetchProfile()
    }
    
    /// Fetches the profile from remote source and updates the local cache.
    func fetchProfile() async throws -> ProfileEntity {
        print("Repository: Forcing remote fetch.")
        let dto = try await remoteDataSource.fetchProfile()
        let entity = dto.toDomain()
        
        // Cache the newly retrieved entity locally
        try? localDataSource.saveProfile(entity)
        
        return entity
    }
}
