//
//  UserProfileView.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/22/26.
//

import SwiftUI

struct UserProfileView: View {
    @StateObject private var profileService = UserProfileService()
    @State private var displayName = ""
    @State private var lastName = ""
    @State private var showingEditor = false
    @State private var showingError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Mi perfil")
                    .font(.title2)
                    .fontWeight(.bold)

                if profileService.isLoading {
                    ProgressView("Cargando perfil...")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if let profile = profileService.currentUser {
                    profileCard(profile)
                } else {
                    emptyProfileState
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    profileService.loadCurrentUser()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                Form {
                    Section("Datos del usuario") {
                        TextField("Nombre", text: $displayName)
                        TextField("Apellido", text: $lastName)
                    }

                    Section("Cuenta") {
                        Text(profileService.currentUser?.email ?? "Se usará el correo autenticado")
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(profileService.currentUser == nil ? "Crear perfil" : "Editar perfil")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            showingEditor = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            profileService.saveUser(displayName: displayName, lastName: lastName) { success in
                                if success {
                                    showingEditor = false
                                }
                            }
                        }
                        .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            profileService.loadCurrentUser()
        }
        .onChange(of: profileService.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .alert("Perfil", isPresented: $showingError) {
            Button("OK") {
                profileService.errorMessage = nil
            }
        } message: {
            Text(profileService.errorMessage ?? "Ocurrió un error al manejar el perfil.")
        }
    }

    private func profileCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 88, height: 88)
                .overlay {
                    Text(profile.initials)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            VStack(spacing: 6) {
                Text(profile.fullName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(profile.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                statCard(title: "Mensajes", value: "\(profile.messageCount)", color: .blue)
                statCard(title: "Apellido", value: profile.lastName, color: .green)
            }

            Button {
                displayName = profile.displayName
                lastName = profile.lastName
                showingEditor = true
            } label: {
                Label("Editar perfil", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var emptyProfileState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Sin perfil",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Crea tu perfil para ver tu nombre, apellido y contador de mensajes.")
            )

            Button {
                displayName = ""
                lastName = ""
                showingEditor = true
            } label: {
                Label("Crear perfil", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        UserProfileView()
    }
}
