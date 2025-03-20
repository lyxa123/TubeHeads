import SwiftUI

struct HomepageView: View {
    @Binding var showSignInView: Bool

    var body: some View {
        NavigationStack {
            VStack {
                Text("TubeHeads")
                    .font(.largeTitle)
                    .padding()

                Spacer()

                // Settings Button
                NavigationLink(destination: SettingsView(showSignInView: $showSignInView)) {
                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Home")
        }
    }
}
