import Foundation
import FirebaseAuth

class CheckFirstOpenToday {
    static let shared = CheckFirstOpenToday()

    private init() {}

    func checkAndStoreDailyEmotionsIfNeeded(viewModel: ChatViewModel) {
        print("Checking if daily emotions need to be stored...")
        let now = Date()
        let calendar = Calendar.current

        if let userID = Auth.auth().currentUser?.uid {
            print("User ID: \(userID)")
            if let lastStoredDate = UserDefaults.standard.object(forKey: "lastStoredDate") as? Date {
                print("Last stored date: \(lastStoredDate)")
                if !calendar.isDateInToday(lastStoredDate) {
                    print("Last stored date is not today, storing emotions and clearing for new day...")
                    viewModel.loadDailyTopEmotions() // Load the dailyTopEmotions array
                    if !viewModel.dailyTopEmotions.isEmpty {
                        print("Top emotions available: \(viewModel.dailyTopEmotions)")
                        viewModel.storeDailyEmotionsToFirebase {
                            print("Emotions stored successfully. Now clearing emotions.")
                            viewModel.clearDailyEmotions() // Clear emotions for the new day after storing
                            NotificationCenter.default.post(name: .updateDailyScore, object: nil, userInfo: ["score": 0.0]) // Send notification to clear average score
                        }
                    } else {
                        print("No top emotions to store.")
                        viewModel.clearDailyEmotions() // Clear emotions if empty
                        NotificationCenter.default.post(name: .updateDailyScore, object: nil, userInfo: ["score": 0.0]) // Send notification to clear average score
                    }
                    UserDefaults.standard.set(now, forKey: "lastStoredDate")
                } else {
                    print("Emotions already stored for today.")
                }
            } else {
                print("No last stored date found, storing emotions and clearing for new day...")
                viewModel.loadDailyTopEmotions() // Load the dailyTopEmotions array
                if !viewModel.dailyTopEmotions.isEmpty {
                    print("Top emotions available: \(viewModel.dailyTopEmotions)")
                    viewModel.storeDailyEmotionsToFirebase {
                        print("Emotions stored successfully. Now clearing emotions.")
                        viewModel.clearDailyEmotions() // Clear emotions for the new day after storing
                        NotificationCenter.default.post(name: .updateDailyScore, object: nil, userInfo: ["score": 0.0]) // Send notification to clear average score
                    }
                } else {
                    print("No top emotions to store.")
                    viewModel.clearDailyEmotions() // Clear emotions if empty
                    NotificationCenter.default.post(name: .updateDailyScore, object: nil, userInfo: ["score": 0.0]) // Send notification to clear average score
                }
                UserDefaults.standard.set(now, forKey: "lastStoredDate")
            }
        } else {
            print("No user ID found, cannot store emotions.")
        }
    }
}
