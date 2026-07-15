//
//  ProfileLocalDataSource.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation

protocol ProfileLocalDataSourceProtocol {
    /// Retrieve the locally cached profile.
    func getSavedProfile() throws -> ProfileEntity?
    
    /// Persist the profile locally.
    func saveProfile(_ profile: ProfileEntity) throws
}

/// A lightweight, UserDefaults-backed local data source for cache operations.
/// Used to keep this reference project self-contained and immediately runnable.
final class ProfileLocalDataSourceImpl: ProfileLocalDataSourceProtocol {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "com.architecturereference.cache.profile"
    
    init() {}
    
    func getSavedProfile() throws -> ProfileEntity? {
        guard let dict = userDefaults.dictionary(forKey: cacheKey) else {
            return nil
        }
        
        let avatarUrl: URL?
        if let avatarString = dict["avatarUrl"] as? String {
            avatarUrl = URL(string: avatarString)
        } else {
            avatarUrl = nil
        }
        
        return ProfileEntity(
            id: dict["id"] as? String ?? "",
            email: dict["email"] as? String ?? "",
            firstName: dict["firstName"] as? String ?? "",
            lastName: dict["lastName"] as? String ?? "",
            phoneNumber: dict["phoneNumber"] as? String ?? "",
            address: dict["address"] as? String ?? "",
            birthDate: dict["birthDate"] as? String ?? "",
            position: dict["position"] as? String ?? "",
            avatarUrl: avatarUrl
        )
    }
    
    func saveProfile(_ profile: ProfileEntity) throws {
        var dict: [String: Any] = [
            "id": profile.id,
            "email": profile.email,
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "phoneNumber": profile.phoneNumber,
            "address": profile.address,
            "birthDate": profile.birthDate,
            "position": profile.position
        ]
        
        if let avatarStr = profile.avatarUrl?.absoluteString {
            dict["avatarUrl"] = avatarStr
        }
        
        userDefaults.set(dict, forKey: cacheKey)
    }
}

/*
// --- REALM DATABASE EQUIVALENT REFERENCE ---
// If you integrate Realm, define your database schema like this:
//
import RealmSwift

class ProfileRealmObject: Object {
    @objc dynamic var id: String = ""
    @objc dynamic var email: String = ""
    @objc dynamic var firstName: String = ""
    @objc dynamic var lastName: String = ""
    @objc dynamic var phoneNumber: String = ""
    @objc dynamic var address: String = ""
    @objc dynamic var birthDate: String = ""
    @objc dynamic var position: String = ""
    @objc dynamic var avatarUrlString: String? = nil
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    func toDomain() -> ProfileEntity {
        return ProfileEntity(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            address: address,
            birthDate: birthDate,
            position: position,
            avatarUrl: avatarUrlString.flatMap { URL(string: $0) }
        )
    }
    
    static func from(entity: ProfileEntity) -> ProfileRealmObject {
        let object = ProfileRealmObject()
        object.id = entity.id
        object.email = entity.email
        object.firstName = entity.firstName
        object.lastName = entity.lastName
        object.phoneNumber = entity.phoneNumber
        object.address = entity.address
        object.birthDate = entity.birthDate
        object.position = entity.position
        object.avatarUrlString = entity.avatarUrl?.absoluteString
        return object
    }
}

final class RealmProfileLocalDataSource: ProfileLocalDataSourceProtocol {
    private let realmProvider: () throws -> Realm
    
    init(realmProvider: @escaping () throws -> Realm = { try Realm() }) {
        self.realmProvider = realmProvider
    }
    
    func getSavedProfile() throws -> ProfileEntity? {
        let realm = try realmProvider()
        guard let realmObject = realm.objects(ProfileRealmObject.self).first else {
            return nil
        }
        return realmObject.toDomain()
    }
    
    func saveProfile(_ profile: ProfileEntity) throws {
        let realm = try realmProvider()
        let realmObject = ProfileRealmObject.from(entity: profile)
        
        try realm.write {
            realm.add(realmObject, update: .modified)
        }
    }
}
*/
