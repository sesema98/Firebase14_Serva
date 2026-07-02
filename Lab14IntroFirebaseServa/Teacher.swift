//
//  Teacher.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 7/2/26.
//

import Foundation
import FirebaseFirestore

struct Teacher: Identifiable, Hashable {
    var id: String
    var fullName: String
    var email: String
    var department: String
    var office: String
    var createdAt: Date

    nonisolated init(
        id: String = UUID().uuidString,
        fullName: String,
        email: String,
        department: String,
        office: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.department = department.trimmingCharacters(in: .whitespacesAndNewlines)
        self.office = office.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }

    nonisolated var departmentKey: String {
        Self.normalizedDepartment(department)
    }

    nonisolated var firestoreData: [String: Any] {
        [
            "fullName": fullName,
            "email": email,
            "department": department,
            "departmentKey": departmentKey,
            "office": office,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    nonisolated static func from(document: QueryDocumentSnapshot) -> Teacher? {
        let data = document.data()

        guard
            let fullName = data["fullName"] as? String,
            let email = data["email"] as? String,
            let department = data["department"] as? String,
            let office = data["office"] as? String
        else {
            return nil
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return Teacher(
            id: document.documentID,
            fullName: fullName,
            email: email,
            department: department,
            office: office,
            createdAt: createdAt
        )
    }

    nonisolated static func normalizedDepartment(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
