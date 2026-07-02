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
    @State private var currentUser: User?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var authStateListener: AuthStateDidChangeListenerHandle?

    var body: some View {
        NavigationStack {
            Group {
                if let currentUser {
                    TeacherHubView(currentUser: currentUser, onSignOut: signOut)
                } else {
                    loginCard
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
    }

    private var loginCard: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.14),
                    Color(red: 0.04, green: 0.05, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 24) {
                    Circle()
                        .fill(Color(red: 0.16, green: 0.73, blue: 0.56).opacity(0.18))
                        .frame(width: 86, height: 86)
                        .overlay {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color(red: 0.16, green: 0.73, blue: 0.56))
                        }

                    VStack(spacing: 10) {
                        Text("DocenteHub")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Horarios y docentes en una sola conversación.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        loginFeatureRow("Consulta horarios por docente, curso o aula.")
                        loginFeatureRow("Explora el directorio y filtra por departamento.")
                        loginFeatureRow("Configura tu servidor IA una sola vez.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Button("Continuar con Google") {
                        signInWithGoogle()
                    }
                    .buttonStyle(GoogleButtonStyle())
                }
                .padding(24)
                .background(Color.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32))

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loginFeatureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.16, green: 0.73, blue: 0.56))
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
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
            .foregroundStyle(.black)
            .padding()
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
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
