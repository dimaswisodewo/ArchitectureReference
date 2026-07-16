//
//  URLSessionNetworkClient.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 16/07/26.
//

import Foundation

/// URLSession-backed implementation of the NetworkClient interface.
/// Serves as a pure Swift native alternative to Moya, allowing execution without external pods.
final class URLSessionNetworkClient: NetworkClient {
    
    init() {}
    
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        var url = endpoint.baseURL
        if !endpoint.path.isEmpty {
            url = url.appendingPathComponent(endpoint.path)
        }
        
        // 1. Setup Query Parameters for GET requests
        if case .requestParameters(let parameters, let encoding) = endpoint.task, encoding == .url {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            if let urlWithParams = urlComponents?.url {
                url = urlWithParams
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // 2. Setup Headers
        if let endpointHeaders = endpoint.headers {
            for (key, value) in endpointHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 3. Setup Request Body
        switch endpoint.task {
        case .requestPlain:
            break
        case .requestParameters(let parameters, let encoding):
            if encoding == .json {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        case .requestJSONEncodable(let encodable):
            request.httpBody = try JSONEncoder().encode(encodable)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // 4. Execute Network Request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 5. Validate Response Status Code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "NetworkClient",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"]
            )
        }
        
        // 6. Decode Data
        let decoder = JSONDecoder()
        // Support custom formats (e.g. snake_case conversion if API dictates)
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(T.self, from: data)
    }
}
