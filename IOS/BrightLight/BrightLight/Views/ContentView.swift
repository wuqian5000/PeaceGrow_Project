import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var wellnessPlanViewModel: WellnessPlanViewModel // Add this line

    var body: some View {
        Group {
            if authViewModel.userSession != nil {
                MainTabView()
                    .environmentObject(chatViewModel)
                    .environmentObject(wellnessPlanViewModel) // Add this line
            } else {
                SignInEmailView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
            .environmentObject(ChatViewModel())
            .environmentObject(WellnessPlanViewModel()) // Add this line
    }
}
