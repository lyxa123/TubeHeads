import SwiftUI

struct SearchFriendsView: View {
    @State private var searchText = ""
    @State private var searchResults: [AppUser] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack {
                TextField("Start typing to find a user...", text: $searchText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding()

                if isLoading {
                    ProgressView()
                }

                List(searchResults) { user in
                    NavigationLink(destination: UserProfileView(userId: user.id)) {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: user.profileImageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                            Text(user.username)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Find Friends")
            .onChange(of: searchText) { _ in
                searchUsers()
            }
        }
    }

    private func searchUsers() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        UserService.searchUsers(by: searchText) { result in
            isLoading = false
            switch result {
            case .success(let users):
                self.searchResults = users
            case .failure(let error):
                print("Search error: \(error)")
            }
        }
    }
}
