//
//  Post.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/22/26.
//

import Foundation
import FirebaseFirestore

struct Post: Identifiable, Hashable {
    var id: String
    var title: String
    var content: String
    var authorEmail: String
    var category: String
    var likes: Int
    var isPublished: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        authorEmail: String,
        likes: Int,
        category: String
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.authorEmail = authorEmail
        self.category = category
        self.likes = likes
        self.isPublished = true
        self.createdAt = Date()
    }

    nonisolated static func from(document: QueryDocumentSnapshot) -> Post? {
        let data = document.data()
        guard
            let title = data["title"] as? String,
            let content = data["content"] as? String,
            let authorEmail = data["authorEmail"] as? String,
            let category = data["category"] as? String
        else {
            return nil
        }

        let likes = data["likes"] as? Int ?? 0
        let isPublished = data["isPublished"] as? Bool ?? true
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return Post(
            id: document.documentID,
            title: title,
            content: content,
            authorEmail: authorEmail,
            likes: likes,
            category: category
        )
        .updated(isPublished: isPublished, createdAt: createdAt)
    }

    var firestoreData: [String: Any] {
        [
            "title": title,
            "content": content,
            "authorEmail": authorEmail,
            "category": category,
            "likes": likes,
            "isPublished": isPublished,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    nonisolated private func updated(isPublished: Bool, createdAt: Date) -> Post {
        var copy = self
        copy.isPublished = isPublished
        copy.createdAt = createdAt
        return copy
    }
}
