import SwiftUI
import UIKit

struct FirebaseRulesView: View {
    @Environment(\.presentationMode) var presentationMode
    let rulesText = """
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
"""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Firebase Security Rules")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text("If you're experiencing 'Missing or insufficient permissions' errors, you need to update your Firebase Firestore security rules. Follow these steps:")
                        .padding(.bottom, 10)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Go to the Firebase Console")
                            .fontWeight(.semibold)
                        Text("2. Select your project")
                            .fontWeight(.semibold)
                        Text("3. Click on 'Firestore Database' in the left menu")
                            .fontWeight(.semibold)
                        Text("4. Click on the 'Rules' tab")
                            .fontWeight(.semibold)
                        Text("5. Replace the existing rules with the following:")
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Firestore Rules:")
                            .fontWeight(.semibold)
                            .padding(.bottom, 5)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                            
                            VStack(alignment: .leading) {
                                Text(rulesText)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                            }
                        }
                        .frame(height: 170)
                        
                        Button {
                            UIPasteboard.general.string = rulesText
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy to Clipboard")
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color(UIColor(red: 0.965, green: 0.745, blue: 0.745, alpha: 1.0)))
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .padding(.top, 10)
                    }
                    
                    Text("After updating the rules, click 'Publish' and wait a few moments for the rules to take effect.")
                        .padding(.top, 10)
                    
                    Text("Note: These rules allow any authenticated user to read and write to your database. For production applications, you should implement more restrictive rules.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    FirebaseRulesView()
} 