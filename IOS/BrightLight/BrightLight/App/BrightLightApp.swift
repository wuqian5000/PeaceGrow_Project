import SwiftUI
import Firebase

@main
struct BrightLightApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var chatViewModel = ChatViewModel()
    @StateObject var wellnessPlanViewModel = WellnessPlanViewModel() // Add this line
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(chatViewModel)
                .environmentObject(wellnessPlanViewModel) // Add this line
                .background(Color.white)
                .onAppear {
                    print("BrightLightApp onAppear called")
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        for window in scene.windows {
                            window.overrideUserInterfaceStyle = .light
                        }
                    }
                    print("Calling checkAndStoreDailyEmotions from BrightLightApp")
                    CheckFirstOpenToday.shared.checkAndStoreDailyEmotionsIfNeeded(viewModel: chatViewModel)
                }
        }
    }
}
