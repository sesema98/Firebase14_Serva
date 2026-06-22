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
    @State private var showingProfile = false

    var body: some View {
        VStack(spacing: 16) {
            header

            if databaseService.messages.isEmpty {
                ContentUnavailableView(
                    "Sin mensajes",
                    systemImage: "ellipsis.message",
                    description: Text("Escribe el primer mensaje para probar Firebase y luego revisa el Profile.")
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
        .alert("Firebase", isPresented: $showError) {
            Button("OK") {
                databaseService.errorMessage = nil
            }
        } message: {
            Text(databaseService.errorMessage ?? "Ocurrió un error al usar Firebase.")
        }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                UserProfileView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Messages")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(currentUser.email ?? "sin-correo@firebase.local")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink(destination: QueryTestView()) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 12) {
                Button("Profile") {
                    showingProfile = true
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                Button("Sign Out", action: onSignOut)
                    .buttonStyle(SignOutButtonStyle())
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 4)

            Button("Send") {
                let currentText = messageText
                databaseService.sendMessage(text: currentText, from: currentUser) { result in
                    if case .success = result {
                        messageText = ""
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 110)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

#Preview {
    AuthView()
}
