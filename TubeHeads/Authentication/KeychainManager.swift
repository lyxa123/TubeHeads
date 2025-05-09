import Foundation
import Security

class KeychainManager {
    private let service = "com.tubeheads.app"
    private let account = "TubeHeadsAccount"
    private let emailKey = "TubeHeadsEmail"
    private let passwordKey = "TubeHeadsPassword"
    
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
    }
    
    // Save email and password to keychain
    func save(email: String, password: String) throws {
        // First delete any existing items
        try deleteCredentials()
        
        // Save email
        guard let emailData = email.data(using: .utf8) else {
            return
        }
        
        var queryEmail: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: emailKey as AnyObject,
            kSecValueData as String: emailData as AnyObject
        ]
        
        let statusEmail = SecItemAdd(queryEmail as CFDictionary, nil)
        
        if statusEmail != errSecSuccess {
            throw KeychainError.unhandledError(status: statusEmail)
        }
        
        // Save password
        guard let passwordData = password.data(using: .utf8) else {
            return
        }
        
        var queryPassword: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: passwordKey as AnyObject,
            kSecValueData as String: passwordData as AnyObject
        ]
        
        let statusPassword = SecItemAdd(queryPassword as CFDictionary, nil)
        
        if statusPassword != errSecSuccess {
            throw KeychainError.unhandledError(status: statusPassword)
        }
    }
    
    // Retrieve email and password from keychain
    func retrieveCredentials() throws -> (email: String, password: String) {
        // Retrieve email
        let emailQuery: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: emailKey as AnyObject,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var emailResult: AnyObject?
        let emailStatus = SecItemCopyMatching(emailQuery as CFDictionary, &emailResult)
        
        guard emailStatus != errSecItemNotFound else {
            throw KeychainError.noPassword
        }
        
        guard emailStatus == errSecSuccess else {
            throw KeychainError.unhandledError(status: emailStatus)
        }
        
        guard let emailData = emailResult as? Data,
              let email = String(data: emailData, encoding: .utf8) else {
            throw KeychainError.unexpectedPasswordData
        }
        
        // Retrieve password
        let passwordQuery: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: passwordKey as AnyObject,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var passwordResult: AnyObject?
        let passwordStatus = SecItemCopyMatching(passwordQuery as CFDictionary, &passwordResult)
        
        guard passwordStatus != errSecItemNotFound else {
            throw KeychainError.noPassword
        }
        
        guard passwordStatus == errSecSuccess else {
            throw KeychainError.unhandledError(status: passwordStatus)
        }
        
        guard let passwordData = passwordResult as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return (email, password)
    }
    
    // Delete credentials from keychain
    func deleteCredentials() throws {
        // Delete email
        let emailQuery: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: emailKey as AnyObject
        ]
        
        let emailStatus = SecItemDelete(emailQuery as CFDictionary)
        
        // Ignore not found error
        if emailStatus != errSecSuccess && emailStatus != errSecItemNotFound {
            throw KeychainError.unhandledError(status: emailStatus)
        }
        
        // Delete password
        let passwordQuery: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: passwordKey as AnyObject
        ]
        
        let passwordStatus = SecItemDelete(passwordQuery as CFDictionary)
        
        // Ignore not found error
        if passwordStatus != errSecSuccess && passwordStatus != errSecItemNotFound {
            throw KeychainError.unhandledError(status: passwordStatus)
        }
    }
    
    // Check if credentials exist
    func hasCredentials() -> Bool {
        do {
            let _ = try retrieveCredentials()
            return true
        } catch {
            return false
        }
    }
} 