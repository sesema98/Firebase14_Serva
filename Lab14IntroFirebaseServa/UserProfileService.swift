//
//  UserProfileService.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/22/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class UserProfileService: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let usersCollection = Firestore.firestore().collection("users")

    func loadCurrentUser() {
        guard let firebaseUser = Auth.auth().currentUser else {
            DispatchQueue.main.async {
                self.currentUser = nil
            }
            return
        }

        isLoading = true
        errorMessage = nil

        usersCollection.document(firebaseUser.uid).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error {
                    self?.errorMessage = "No se pudo cargar el perfil: \(error.localizedDescription)"
                    return
                }

                guard let self else {
                    return
                }

                guard let document, document.exists else {
                    self.currentUser = nil
                    return
                }

                self.currentUser = UserProfile.from(id: document.documentID, data: document.data() ?? [:])
            }
        }
    }

    func saveUser(
        displayName: String,
        lastName: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard
            let firebaseUser = Auth.auth().currentUser,
            let email = firebaseUser.email
        else {
            errorMessage = "No hay una sesión activa para guardar el perfil."
            completion?(false)
            return
        }

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDisplayName.isEmpty, !trimmedLastName.isEmpty else {
            errorMessage = "Completa nombre y apellido."
            completion?(false)
            return
        }

        let profile = UserProfile(
            id: firebaseUser.uid,
            email: email,
            displayName: trimmedDisplayName,
            lastName: trimmedLastName,
            messageCount: currentUser?.messageCount ?? 0
        )

        usersCollection.document(firebaseUser.uid).setData(profile.firestoreData, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = "No se pudo guardar el perfil: \(error.localizedDescription)"
                    completion?(false)
                    return
                }

                self?.currentUser = profile
                completion?(true)
            }
        }
    }

    func incrementMessageCountIfProfileExists() {
        guard let firebaseUser = Auth.auth().currentUser else {
            return
        }

        let document = usersCollection.document(firebaseUser.uid)
        document.getDocument { [weak self] snapshot, error in
            guard error == nil, let snapshot, snapshot.exists else {
                return
            }

            document.updateData([
                "messageCount": FieldValue.increment(Int64(1))
            ]) { updateError in
                guard updateError == nil else {
                    return
                }

                DispatchQueue.main.async {
                    self?.currentUser?.messageCount += 1
                }
            }
        }
    }
}
