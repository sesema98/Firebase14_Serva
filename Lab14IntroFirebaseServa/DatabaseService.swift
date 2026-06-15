//
//  DatabaseService.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/15/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let email: String
    let text: String
    let sentAt: Date
}

final class DatabaseService: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var errorMessage: String?

    private let messagesCollection: CollectionReference
    private var messagesListener: ListenerRegistration?

    init() {
        messagesCollection = Firestore.firestore().collection("messages")
    }

    func startListening() {
        guard messagesListener == nil else {
            return
        }

        messagesListener = messagesCollection
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
            guard let self else {
                return
            }

            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = Self.userFacingMessage(for: error)
                }
                return
            }

            guard let documents = snapshot?.documents else {
                return
            }

            let parsedMessages = documents.compactMap { document -> ChatMessage? in
                let data = document.data()
                guard
                    let email = data["email"] as? String,
                    let text = data["text"] as? String
                else {
                    return nil
                }

                return ChatMessage(
                    id: document.documentID,
                    email: email,
                    text: text,
                    sentAt: (data["timestamp"] as? Timestamp)?.dateValue() ?? .distantPast
                )
            }
            .sorted { $0.sentAt < $1.sentAt }

            DispatchQueue.main.async {
                self.messages = parsedMessages
            }
        }
    }

    func stopListening() {
        guard let messagesListener else {
            return
        }

        messagesListener.remove()
        self.messagesListener = nil
    }

    func sendMessage(text: String, from user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            completion(.success(()))
            return
        }

        let payload: [String: Any] = [
            "email": user.email ?? "sin-correo@firebase.local",
            "text": trimmedText,
            "timestamp": FieldValue.serverTimestamp()
        ]

        messagesCollection.addDocument(data: payload) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = Self.userFacingMessage(for: error)
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        let message = error.localizedDescription

        if message.localizedCaseInsensitiveContains("permission denied") {
            return "Firebase rechazo la operacion por reglas de Cloud Firestore. Verifica que tus reglas permitan leer y escribir con request.auth != null."
        }

        if message.localizedCaseInsensitiveContains("network")
            || message.localizedCaseInsensitiveContains("could not")
            || message.localizedCaseInsensitiveContains("host")
        {
            return "No se pudo conectar a Cloud Firestore. Revisa que la base exista y que la app iOS registrada en Firebase coincida con el bundle identifier del proyecto."
        }

        return message
    }
}
