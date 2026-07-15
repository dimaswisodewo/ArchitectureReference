//
//  ProfileDTO.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

struct ProfileResponseDTO: Codable {
    let meta: ResponseMetaDTO
    let data: ProfileDTO?
}

struct ResponseMetaDTO: Codable {
    let error: Bool
    let code: Int
    let message: String
}

struct ProfileDTO: Codable {
    let id: Int
    let userid: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let phoneNumber: String?
    let address: String?
    let birthDate: String?
    let position: String?
    let avatar: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userid
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case phoneNumber = "phone_number"
        case address
        case birthDate = "birth_date"
        case position
        case avatar
    }
    
    func toDomain() -> ProfileEntity {
        return ProfileEntity(
            id: String(id),
            email: email ?? "",
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            phoneNumber: phoneNumber ?? "",
            address: address ?? "",
            birthDate: birthDate ?? "",
            position: position ?? "",
            avatarUrl: avatar.flatMap { URL(string: $0) }
        )
    }
}
