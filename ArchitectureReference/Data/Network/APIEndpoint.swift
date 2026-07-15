//
//  APIEndpoint.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

/// Defines the contract for HTTP method types.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Defines parameter encoding methods.
enum ParameterEncoding {
    case url
    case json
}

/// Defines the type of request body task.
enum HTTPTask {
    /// No parameters or request body.
    case requestPlain
    
    /// Key-value parameters passed either in query string or as request body.
    case requestParameters(parameters: [String: Any], encoding: ParameterEncoding)
    
    /// Encodable object serialized directly to JSON request body.
    case requestJSONEncodable(encodable: Encodable)
}

/// The blueprint protocol that all feature endpoints must conform to.
/// Decoupled from any network implementation details.
protocol APIEndpoint {
    /// Base URL of the API service.
    var baseURL: URL { get }
    
    /// Path route for this specific endpoint.
    var path: String { get }
    
    /// HTTP Method (GET, POST, PUT, DELETE).
    var method: HTTPMethod { get }
    
    /// Custom HTTP header dictionary.
    var headers: [String: String]? { get }
    
    /// Specific request structure task.
    var task: HTTPTask { get }
}
