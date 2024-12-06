import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @StateObject var chatViewModel = ChatViewModel()
    @StateObject var wellnessPlanViewModel = WellnessPlanViewModel()
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if viewModel.isAuthenticated {
                NavigationStack {  // Use NavigationView for iOS 15 and earlier
                    TabView(selection: $selectedTab) {
                        DiscoverView(selectedTab: $selectedTab)
                            .tabItem {
                                Image(systemName: "magnifyingglass")
                                Text("Discover")
                            }
                            .tag(0)
                        
                        ChatView()
                            .tabItem {
                                Image(systemName: "message")
                                Text("Chat")
                            }
                            .tag(1)
                        
                        ProfileView(chatViewModel: chatViewModel)
                            .tabItem {
                                Image(systemName: "person")
                                Text("Profile")
                            }
                            .tag(2)
                    }
                    .background(Color.white)
                    .edgesIgnoringSafeArea(.all)
                }
                .environmentObject(viewModel)
                .environmentObject(chatViewModel)
                .environmentObject(wellnessPlanViewModel)
            } else {
                SignInEmailView()
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            Task {
                await viewModel.checkAuthenticationState()
            }
        }
    }
}
