//
//  ProfileRemoteDataSource.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

enum ProfileEndpoint: APIEndpoint {
    case getProfile
    
    var baseURL: URL {
        return URL(string: "https://api.example.com")!
    }
    
    var path: String {
        return "/api/v1/profile"
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var headers: [String: String]? {
        return [
            "Authorization": "Bearer sample_token",
            "Accept": "application/json"
        ]
    }
    
    var task: HTTPTask {
        return .requestPlain
    }
}

protocol ProfileRemoteDataSourceProtocol {
    func fetchProfile() async throws -> ProfileDTO
}

final class ProfileRemoteDataSourceImpl: ProfileRemoteDataSourceProtocol {
    private let networkClient: NetworkClient
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
    
    func fetchProfile() async throws -> ProfileDTO {
        do {
            // Attempt to hit the network client endpoint
            let response: ProfileResponseDTO = try await networkClient.request(ProfileEndpoint.getProfile)
            if let data = response.data {
                return data
            }
            throw NSError(
                domain: "ProfileRemoteDataSource",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Profile data was empty in response."]
            )
        } catch {
            // Log the error and return local mock representation for instant runnability
            print("RemoteDataSource: Remote server unreachable. Mocking remote data for preview. (\(error.localizedDescription))")
            
            // Artificial delay to simulate network latency
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            return ProfileDTO(
                id: 1089,
                userid: "APPLE-ID-99281",
                email: "developer@apple.com",
                firstName: "Meynabel Dimas",
                lastName: "Wisodewo",
                phoneNumber: "+6281122334455",
                address: "Apple Park, Cupertino, CA",
                birthDate: "1994-08-23",
                position: "Software Engineer - iOS",
                avatar: "https://api.dicebear.com/7.x/adventurer/svg?seed=Dimas"
            )
        }
    }
}
