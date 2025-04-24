import SwiftUI
import FirebaseAuth

// Add this to debug authentication issues in AuthManager.swift
func debugAuthState() {
    if let currentUser = Auth.auth().currentUser {
        print("Auth Debug: User is signed in with ID: \(currentUser.uid)")
        print("Auth Debug: Email verified: \(currentUser.isEmailVerified)")
    } else {
        print("Auth Debug: No user is currently signed in")
    }
} 