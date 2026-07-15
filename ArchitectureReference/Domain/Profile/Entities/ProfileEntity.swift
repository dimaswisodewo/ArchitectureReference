//
//  ProfileEntity.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

struct ProfileEntity: Identifiable, Equatable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let address: String
    let birthDate: String
    let position: String
    let avatarUrl: URL?
    
    var fullName: String {
        if firstName.isEmpty && lastName.isEmpty {
            return "-"
        }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
