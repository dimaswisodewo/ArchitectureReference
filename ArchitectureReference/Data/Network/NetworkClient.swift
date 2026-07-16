//
//  NetworkClient.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

/// Abstraction layer for network requests. Decouples Remote Data Sources
/// from third-party networking engines (like Moya, Alamofire, or URLSession).
protocol NetworkClient {
    /// Executes an async network request and returns the decoded decodable model.
    /// - Parameter endpoint: The generic endpoint definition.
    /// - Returns: Decoded decodable model.
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}
