//
//  GoogleAuthManager.swift
//  Cira
//
//  Native Google Sign-In integration
//

import Foundation
import GoogleSignIn

@MainActor
final class GoogleAuthManager {
    static let shared = GoogleAuthManager()
    
    private init() {
        // GIDSignIn automatically reads configuration from GoogleService-Info.plist / Info.plist
        // Ensure you have added GoogleService-Info.plist to your project
    }
    
    /// Perform Native Google Sign-In and return the ID Token
    func signIn() async throws -> String {
        // Get the top-most view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw GoogleAuthError.noRootViewController
        }
        
        // Find the top-most presented controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Perform sign-in
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topController)
        
        // Extract ID Token
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleAuthError.missingIdToken
        }
        
        return idToken
    }
    
    /// Handle URL callback (for older iOS versions)
    func handle(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Errors
enum GoogleAuthError: LocalizedError {
    case noRootViewController
    case missingIdToken
    
    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Could not find root view controller"
        case .missingIdToken:
            return "Google Sign-In did not return an ID token"
        }
    }
}
