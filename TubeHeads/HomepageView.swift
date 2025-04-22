import SwiftUI

struct HomepageView: View {
    @Binding var showSignInView: Bool
    @State private var showMenu = false
    @State private var navigateToSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    Text("TubeHeads")
                        .font(.largeTitle)
                        .padding()
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Slide-out menu
                if showMenu {
                    SideMenuView(
                        showMenu: $showMenu,
                        showSignInView: $showSignInView
                    )
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }
                
                NavigationLink(destination: SettingsView(showSignInView: $showSignInView), isActive: $navigateToSettings) {
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            showMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Search functionality would go here
                    }) {
                        Image(systemName: "magnifyingglass")
                            .imageScale(.large)
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 50 {
                        withAnimation {
                            showMenu = true
                        }
                    } else if value.translation.width < -50 && showMenu {
                        withAnimation {
                            showMenu = false
                        }
                    }
                }
        )
    }
}

struct SideMenuView: View {
    @Binding var showMenu: Bool
    @Binding var showSignInView: Bool
    @State private var navigateToSettings = false
    
    var body: some View {
        ZStack {
            // Background overlay that dismisses menu when tapped
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showMenu.toggle()
                    }
                }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation {
                                showMenu.toggle()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                                .imageScale(.large)
                                .padding()
                        }
                    }
                    
                    // Add padding to push menu items down
                    Spacer()
                        .frame(height: 20)
                    
                    // Profile (non-functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Profile")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Lists (non-functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Lists")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Reviews (non-functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Reviews")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Activities (non-functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flame.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Activities")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Settings (functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Navigate to settings after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToSettings = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Settings")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.blue)
                        .contentShape(Rectangle())
                    }
                    
                    // Log Out (functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Sign out after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            do {
                                try AuthenticationManager.shared.SignOut()
                                showSignInView = true
                            } catch {
                                print("Error signing out: \(error)")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Log Out")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.blue)
                        .contentShape(Rectangle())
                    }
                    
                    NavigationLink(destination: SettingsView(showSignInView: $showSignInView), isActive: $navigateToSettings) {
                        EmptyView()
                    }
                    
                    Spacer()
                }
                .frame(width: 250)
                .background(Color(UIColor.systemBackground))
                .edgesIgnoringSafeArea(.vertical)
                
                Spacer()
            }
        }
    }
}
