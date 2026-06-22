//
//  PostQueryService.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/22/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class PostQueryService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var queryDescription = ""
    @Published var errorMessage: String?

    private let postsCollection = Firestore.firestore().collection("posts")

    func getAllPosts() {
        runQuery(
            description: "ORDER BY createdAt DESC",
            query: postsCollection.order(by: "createdAt", descending: true)
        )
    }

    func getPostsByCategory(_ category: String) {
        runQuery(
            description: "WHERE category == '\(category)'",
            query: postsCollection.whereField("category", isEqualTo: category)
        )
    }

    func getPopularPosts() {
        runQuery(
            description: "WHERE likes > 10 ORDER BY likes DESC",
            query: postsCollection
                .whereField("likes", isGreaterThan: 10)
                .order(by: "likes", descending: true)
        )
    }

    func getTop5PopularPosts() {
        runQuery(
            description: "ORDER BY likes DESC LIMIT 5",
            query: postsCollection
                .order(by: "likes", descending: true)
                .limit(to: 5)
        )
    }

    func getPostsByNewest() {
        runQuery(
            description: "ORDER BY createdAt DESC",
            query: postsCollection.order(by: "createdAt", descending: true)
        )
    }

    func getFirst3Posts() {
        runQuery(
            description: "LIMIT 3",
            query: postsCollection.limit(to: 3)
        )
    }

    func addSamplePosts() {
        let authenticatedEmail = Auth.auth().currentUser?.email ?? "test@tecsup.edu.pe"

        let samplePosts: [Post] = [
            Post(
                title: "Getting Started with SwiftUI",
                content: "SwiftUI es el framework moderno para construir interfaces declarativas.",
                authorEmail: authenticatedEmail,
                likes: 5,
                category: "swift"
            ),
            Post(
                title: "Getting Started with Kotlin",
                content: "Kotlin ofrece una sintaxis moderna para Android.",
                authorEmail: "jfarfan@tecsup.edu.pe",
                likes: 15,
                category: "kotlin"
            ),
            Post(
                title: "iOS Development Tips",
                content: "Buenas prácticas para organizar vistas y servicios.",
                authorEmail: authenticatedEmail,
                likes: 10,
                category: "swift"
            ),
            Post(
                title: "Push Notification Kotlin",
                content: "Cómo integrar mensajería y notificaciones en apps móviles.",
                authorEmail: "jfarfan@tecsup.edu.pe",
                likes: 20,
                category: "kotlin"
            ),
            Post(
                title: "Firebase Basics",
                content: "Conceptos base de autenticación, base de datos y mensajería.",
                authorEmail: "smontoya@tecsup.edu.pe",
                likes: 1,
                category: "google"
            )
        ]

        errorMessage = nil

        for (index, sample) in samplePosts.enumerated() {
            let document = postsCollection.document()
            var post = sample
            post.id = document.documentID
            post.createdAt = Date().addingTimeInterval(-Double(index * 86_400))

            document.setData(post.firestoreData) { [weak self] error in
                if let error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "No se pudo insertar la data de prueba: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func runQuery(description: String, query: Query) {
        isLoading = true
        queryDescription = description
        errorMessage = nil

        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error {
                    self?.errorMessage = "La consulta falló: \(error.localizedDescription)"
                    self?.posts = []
                    return
                }

                guard let documents = snapshot?.documents else {
                    self?.posts = []
                    return
                }

                self?.posts = documents.compactMap(Post.from)
            }
        }
    }
}
