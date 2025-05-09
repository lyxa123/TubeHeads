import SwiftUI
import LocalAuthentication

class BiometricAuthManager: ObservableObject {
    @Published var biometricType: BiometricType = .none
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String = ""
    
    enum BiometricType {
        case none
        case faceID
        case touchID
    }
    
    init() {
        getBiometricType()
    }
    
    // Check what biometric authentication is available on the device
    func getBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
                print("BiometricAuthManager: FaceID is available on this device")
            case .touchID:
                biometricType = .touchID
                print("BiometricAuthManager: TouchID is available on this device")
            default:
                biometricType = .none
                print("BiometricAuthManager: Unknown biometric type available")
            }
        } else {
            biometricType = .none
            if let error = error {
                print("BiometricAuthManager: Biometric not available. Error: \(error.localizedDescription)")
            } else {
                print("BiometricAuthManager: Biometric not available on this device")
            }
        }
    }
    
    // Authenticate using biometrics
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometrics is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            print("BiometricAuthManager: Cannot evaluate policy: \(errorMessage)")
            completion(false)
            return
        }
        
        // Get the correct authentication reason based on the biometric type
        let reason = biometricType == .faceID ? "Authenticate using Face ID" : "Authenticate using Touch ID"
        
        print("BiometricAuthManager: Attempting to authenticate with \(biometricType == .faceID ? "FaceID" : "TouchID")")
        
        // Attempt authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    print("BiometricAuthManager: Authentication successful")
                    completion(true)
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Authentication failed"
                    print("BiometricAuthManager: Authentication failed: \(self.errorMessage)")
                    completion(false)
                }
            }
        }
    }
    
    // Save credentials for a user to enable biometric login
    func saveUserCredentials(email: String, password: String) {
        let keychainItem = KeychainManager()
        
        do {
            try keychainItem.save(email: email, password: password)
            print("BiometricAuthManager: Credentials saved successfully")
        } catch {
            print("BiometricAuthManager: Failed to save credentials: \(error.localizedDescription)")
        }
    }
    
    // Retrieve user credentials from keychain
    func retrieveUserCredentials() -> (email: String, password: String)? {
        let keychainItem = KeychainManager()
        
        do {
            let credentials = try keychainItem.retrieveCredentials()
            print("BiometricAuthManager: Credentials retrieved successfully")
            return credentials
        } catch {
            print("BiometricAuthManager: Failed to retrieve credentials: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Check if user has saved credentials for biometric login
    func hasSavedCredentials() -> Bool {
        let keychainItem = KeychainManager()
        let hasCredentials = keychainItem.hasCredentials()
        print("BiometricAuthManager: Has saved credentials: \(hasCredentials)")
        return hasCredentials
    }
    
    // Remove saved credentials
    func removeCredentials() {
        let keychainItem = KeychainManager()
        
        do {
            try keychainItem.deleteCredentials()
            print("BiometricAuthManager: Credentials removed successfully")
        } catch {
            print("BiometricAuthManager: Failed to delete credentials: \(error.localizedDescription)")
        }
    }
} 