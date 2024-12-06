import UIKit
import Firebase
import FirebaseFirestore

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate didFinishLaunchingWithOptions called")
        
        // Configure Firebase
        FirebaseApp.configure()
        print("Firebase configured")
        
        // Enable Firestore logging
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        print("Firestore logging enabled")
        
        // Ensure UI style is set to light
        if #available(iOS 13.0, *) {
            window?.overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
            UINavigationBar.appearance().barStyle = .default
            UITabBar.appearance().barStyle = .default
        }
        
        return true
    }
}
