//
//  AlamofireNetworkClient.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 16/07/26.
//

import Foundation
import Alamofire

/// Alamofire-backed implementation of the NetworkClient interface.
final class AlamofireNetworkClient: NetworkClient {
    
    init() {}
    
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        var url = endpoint.baseURL
        if !endpoint.path.isEmpty {
            url = url.appendingPathComponent(endpoint.path)
        }
        
        let method = Alamofire.HTTPMethod(rawValue: endpoint.method.rawValue)
        let headers = endpoint.headers.map { HTTPHeaders($0) }
        
        let dataRequest: DataRequest
        
        switch endpoint.task {
        case .requestPlain:
            dataRequest = AF.request(url, method: method, headers: headers)
            
        case .requestParameters(let parameters, let encoding):
            let parameterEncoding: Alamofire.ParameterEncoding
            switch encoding {
            case .url:
                parameterEncoding = URLEncoding.default
            case .json:
                parameterEncoding = JSONEncoding.default
            }
            dataRequest = AF.request(url, method: method, parameters: parameters, encoding: parameterEncoding, headers: headers)
            
        case .requestJSONEncodable(let encodable):
            // Using direct JSONParameterEncoder to serialize encodable object
            dataRequest = AF.request(url, method: method, parameters: encodable, encoder: JSONParameterEncoder.default, headers: headers)
        }
        
        let response = await dataRequest
            .validate(statusCode: 200...299)
            .serializingDecodable(T.self)
            .response
        
        switch response.result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
