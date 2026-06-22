//
//  UserProfile.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/22/26.
//

import Foundation

struct UserProfile: Identifiable, Equatable {
    let id: String
    let email: String
    var displayName: String
    var lastName: String
    var messageCount: Int

    var fullName: String {
        [displayName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var initials: String {
        let parts = [displayName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let letters = parts.compactMap { $0.first }.prefix(2)
        let result = String(letters)
        return result.isEmpty ? "?" : result.uppercased()
    }

    static func from(id: String, data: [String: Any]) -> UserProfile? {
        guard let email = data["email"] as? String else {
            return nil
        }

        let displayName = (data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lastName = (data["lastName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let messageCount = data["messageCount"] as? Int ?? 0

        return UserProfile(
            id: id,
            email: email,
            displayName: displayName,
            lastName: lastName,
            messageCount: messageCount
        )
    }

    var firestoreData: [String: Any] {
        [
            "email": email,
            "displayName": displayName,
            "lastName": lastName,
            "messageCount": messageCount
        ]
    }
}
