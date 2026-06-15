//
//  AuthView.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/15/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var currentUser: User?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var authStateListener: AuthStateDidChangeListenerHandle?

    var body: some View {
        NavigationStack {
            Group {
                if let currentUser {
                    MessagesView(currentUser: currentUser, onSignOut: signOut)
                } else {
                    authenticationForm
                }
            }
        }
        .alert("Firebase Authentication", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            setUpAuthStateListener()
        }
        .onDisappear {
            removeAuthStateListener()
        }
        .onChange(of: currentUser?.uid) { _, newValue in
            if newValue == nil {
                email = ""
                password = ""
            }
        }
    }

    private var authenticationForm: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("Lab 14")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Autenticacion con Firebase")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Correo institucional", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                SecureField("Contrasena", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(spacing: 12) {
                Button("Sign In") {
                    signIn()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Sign Up") {
                    signUp()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Sign In with Google") {
                    signInWithGoogle()
                }
                .buttonStyle(GoogleButtonStyle())
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setUpAuthStateListener() {
        currentUser = Auth.auth().currentUser

        guard authStateListener == nil else {
            return
        }

        authStateListener = Auth.auth().addStateDidChangeListener { _, user in
            currentUser = user
        }
    }

    private func removeAuthStateListener() {
        guard let authStateListener else {
            return
        }

        Auth.auth().removeStateDidChangeListener(authStateListener)
        self.authStateListener = nil
    }

    private func signIn() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validateFields(email: trimmedEmail, password: password) else {
            return
        }

        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { _, error in
            if let error {
                presentAlert(message: error.localizedDescription)
            }
        }
    }

    private func signUp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validateFields(email: trimmedEmail, password: password) else {
            return
        }

        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { _, error in
            if let error {
                presentAlert(message: error.localizedDescription)
            } else {
                presentAlert(message: "Usuario registrado correctamente en Firebase Authentication.")
            }
        }
    }

    private func signOut() {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
            currentUser = nil
        } catch {
            presentAlert(message: error.localizedDescription)
        }
    }

    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            presentAlert(message: "Falta CLIENT_ID en GoogleService-Info.plist. En Firebase Console habilita Google Sign-In y vuelve a descargar ese archivo.")
            return
        }

        guard let presentingViewController = UIApplication.topViewController() else {
            presentAlert(message: "No se encontro una vista para presentar Google Sign-In.")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error {
                presentAlert(message: error.localizedDescription)
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                presentAlert(message: "Google Sign-In no devolvio un token valido.")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    presentAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func validateFields(email: String, password: String) -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            presentAlert(message: "Completa el correo y la contrasena.")
            return false
        }

        guard password.count >= 6 else {
            presentAlert(message: "Firebase requiere una contrasena de al menos 6 caracteres.")
            return false
        }

        return true
    }

    private func presentAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .padding()
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color.blue)
            .padding()
            .background(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.blue, lineWidth: 2)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SignOutButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GoogleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .padding()
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private extension UIApplication {
    static func topViewController(
        base: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topViewController(base: selectedViewController)
        }

        if let presentedViewController = base?.presentedViewController {
            return topViewController(base: presentedViewController)
        }

        return base
    }
}

#Preview {
    AuthView()
}
