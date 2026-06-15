//
//  MessagesView.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/15/26.
//

import SwiftUI
import FirebaseAuth

struct MessagesView: View {
    let currentUser: User
    let onSignOut: () -> Void

    @StateObject private var databaseService = DatabaseService()
    @State private var messageText = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 16) {
            header

            if databaseService.messages.isEmpty {
                ContentUnavailableView(
                    "Sin mensajes",
                    systemImage: "ellipsis.message",
                    description: Text("Escribe el primer mensaje para probar Firebase Database.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(databaseService.messages) { message in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(message.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(message.text)
                            .font(.body)

                        Text(Self.dateFormatter.string(from: message.sentAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }

            composer
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .navigationTitle("Mensajes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            databaseService.startListening()
        }
        .onDisappear {
            databaseService.stopListening()
        }
        .onChange(of: databaseService.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("Firebase Database", isPresented: $showError) {
            Button("OK") {
                databaseService.errorMessage = nil
            }
        } message: {
            Text(databaseService.errorMessage ?? "Ocurrio un error al usar Firebase Database.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Usuario autenticado")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(currentUser.email ?? "sin-correo@firebase.local")
                    .font(.headline)
            }

            Spacer()

            Button("Sign Out", action: onSignOut)
                .buttonStyle(SignOutButtonStyle())
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Escribe un mensaje", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 4)

            Button("Enviar") {
                let currentText = messageText
                databaseService.sendMessage(text: currentText, from: currentUser) { result in
                    if case .success = result {
                        messageText = ""
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 110)
        }
        .padding(.bottom, 12)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
