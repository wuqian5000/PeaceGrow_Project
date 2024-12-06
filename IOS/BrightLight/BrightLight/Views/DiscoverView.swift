import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var viewModel: AuthViewModel
    @EnvironmentObject var wellnessPlanViewModel: WellnessPlanViewModel
    @State private var dailyScore: Double = 0.0
    @State private var showGreeting: Bool = false
    @State private var greetingTexts: [String] = []
    @State private var currentGreetingIndex: Int = 0
    @State private var isRecorded: Bool = false
    @State private var userDataLoaded = false
    @State private var showTwoWeekCheck = false
    @State private var twoWeekStatus: String = "Due"
    @State private var twoWeekCheckCompleted = false
    @State private var showDailyWellnessPlan = false
    @State private var navigateToDailyWellnessPlan = false
    @State private var dailyWellnessPlanDay: Int = 0
    @State private var showTwoWeekCheckView = false
    @Binding var selectedTab: Int
    

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        Group {
            if userDataLoaded {
                VStack {
                    // Emotional face image
                    Image("face_\(max(0, min(100, Int(dailyScore.isNaN ? 0 : dailyScore))))")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)

                    // Daily score with smaller font size
                    Text(dailyScore.isNaN ? "N/A" : String(format: "%.0f", dailyScore))
                        .font(.system(size: 30))

                    if showGreeting && !greetingTexts.isEmpty {
                        HStack {
                            Text(greetingTextShortened(greetingTexts[currentGreetingIndex]))
                                .font(.system(size: 18))
                                .padding()
                                .background(Color.orange.opacity(0.7))
                                .cornerRadius(10)
                                .onTapGesture {
                                    withAnimation {
                                        currentGreetingIndex = (currentGreetingIndex + 1) % greetingTexts.count
                                        isRecorded = chatViewModel.isGreetingRecorded(greetingTexts[currentGreetingIndex])
                                    }
                                }

                            Spacer()

                            Image(systemName: isRecorded ? "record.circle.fill" : "record.circle")
                                .foregroundColor(isRecorded ? .red : .gray)
                                .onTapGesture {
                                    withAnimation {
                                        isRecorded.toggle()
                                        chatViewModel.setGreetingRecorded(greetingTexts[currentGreetingIndex], isRecorded: isRecorded)
                                        if isRecorded {
                                            let alert = UIAlertController(title: nil, message: "You like it, I remember it.", preferredStyle: .alert)
                                            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                alert.dismiss(animated: true)
                                            }
                                        }
                                    }
                                }
                        }
                        .padding()
                    }

                    Spacer()

                    // First row
                    HStack(spacing: 20) {
                        // "Let's Talk" square
                        SquareView(title: "Let's Talk", imageName: "talk")
                            .onTapGesture {
                                withAnimation {
                                    if chatViewModel.messages.isEmpty {
                                        fetchDetailedGreeting()
                                    } else if !chatViewModel.hasUnrepliedGreeting {
                                        let greetingMessage = friendlyGreeting()
                                        chatViewModel.sendBotMessage(greetingMessage)
                                        chatViewModel.hasUnrepliedGreeting = true
                                    }
                                    selectedTab = 1
                                }
                            }

                        // Two-Week Wellness Check square
                        NavigationLink(destination: TwoWeekCheckView(checkCompleted: $twoWeekCheckCompleted)
                            .environmentObject(viewModel)
                            .environmentObject(chatViewModel)) {
                            SquareView(title: "Two-Week Wellness Check", value: twoWeekStatus)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)

                    // Second row
                    HStack(spacing: 20) {
                        NavigationLink(destination: Group {
                            if wellnessPlanViewModel.isTwoWeekCheckDue {
                                TwoWeekCheckView(checkCompleted: $twoWeekCheckCompleted)
                                    .environmentObject(viewModel)
                                    .environmentObject(chatViewModel)
                            } else {
                                DailyWellnessPlanView()
                            }
                        }, isActive: $navigateToDailyWellnessPlan) {
                            SquareView(title: "Daily Self-care Plan", value: wellnessPlanViewModel.isTwoWeekCheckDue ? "Check Now" : "Day \(wellnessPlanViewModel.currentDay)")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onTapGesture{
                            checkAndNavigateToDailyWellnessPlan()
                        }

                        // Top Emotions square
                        SquareView(title: "Top Emotions", content: AnyView(
                            ForEach(chatViewModel.dailyTopEmotions.prefix(3), id: \.name) { emotion in
                                Text("\(emotion.name): \(String(format: "%.2f", emotion.value))")
                                    .font(.subheadline)
                            }
                        ))
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 70)
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if let userID = viewModel.currentUser?.id {
                checkTwoWeekStatus()
                checkDailyWellnessPlanStatus()
                chatViewModel.loadDailyTopEmotions()
                self.dailyScore = chatViewModel.dailyAverageScore
                checkFirstLaunchAndFetchGreeting()
                userDataLoaded = true
            } else {
                print("User not authenticated yet")
            }
        }
        .navigationBarTitle("Discover", displayMode: .inline)
        .onAppear {
            
        }
  
        .onDisappear {
                    NotificationCenter.default.removeObserver(self, name: .updateDailyScore, object: nil)
                }
        .onChange(of: twoWeekCheckCompleted) { oldValue, newValue in
            if newValue {
                twoWeekStatus = "Complete"
                twoWeekCheckCompleted = false  // Reset for next time
            }
        }
    }

    private func checkFirstLaunchAndFetchGreeting() {
        let now = Date()
        let calendar = Calendar.current

        if let lastLaunchDate = UserDefaults.standard.object(forKey: "lastLaunchDate") as? Date {
            if !calendar.isDateInToday(lastLaunchDate) {
                fetchGreetingTexts()
                UserDefaults.standard.set(now, forKey: "lastLaunchDate")
            }
        } else {
            fetchGreetingTexts()
            UserDefaults.standard.set(now, forKey: "lastLaunchDate")
        }
    }

    private func fetchGreetingTexts() {
        chatViewModel.fetchSummary { summary in
            guard let summary = summary else { return }
            let firstName = viewModel.currentUser?.fullname.split(separator: " ").first.map(String.init) ?? "User"
            chatViewModel.generateGreetings(from: summary, firstName: firstName, promptType: .inspire, count: 7) { greetings in
                DispatchQueue.main.async {
                    self.greetingTexts = greetings
                    self.showGreeting = true
                    self.currentGreetingIndex = 0
                    self.isRecorded = chatViewModel.isGreetingRecorded(greetings.first ?? "")
                }
            }
        }
    }

    private func fetchDetailedGreeting() {
        let firstName = viewModel.currentUser?.fullname.split(separator: " ").first.map(String.init) ?? "User"
        chatViewModel.fetchAndSendDetailedGreeting(firstName: firstName)
    }

    private func greetingTextShortened(_ text: String) -> String {
        let words = text.split(separator: " ")
        if words.count > 14 {
            return words.prefix(14).joined(separator: " ") + "..."
        } else {
            return text
        }
    }

    private func friendlyGreeting() -> String {
        let firstName = viewModel.currentUser?.fullname.split(separator: " ").first.map(String.init) ?? "User"
        return "Hi \(firstName), how's it going?"
    }

    private func checkTwoWeekStatus() {
        let userID = viewModel.currentUser?.id ?? ""
        FirestoreManager.shared.fetchLatestTwoWeekCheck(userID: userID) { latestCheckDate, _, _, _, _ in
            if let latestDate = latestCheckDate {
                let currentDate = Date()
                let calendar = Calendar.current
                if let daysDifference = calendar.dateComponents([.day], from: latestDate.dateValue(), to: currentDate).day, daysDifference >= 14 {
                    self.twoWeekStatus = "Due"
                } else {
                    self.twoWeekStatus = "Complete"
                }
            } else {
                self.twoWeekStatus = "Due"
            }
        }
    }

    private func checkAndNavigateToDailyWellnessPlan() {
        wellnessPlanViewModel.checkAndUpdatePlanStatus { _ in
            DispatchQueue.main.async {
                self.navigateToDailyWellnessPlan = true
            }
        }
    }

    private func checkDailyWellnessPlanStatus() {
        wellnessPlanViewModel.checkAndUpdatePlanStatus { day in
            DispatchQueue.main.async {
                self.dailyWellnessPlanDay = day
            }
        }
    }
}
