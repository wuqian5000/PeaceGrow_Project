import SwiftUI
import FirebaseAuth

struct DailyWellnessPlanView: View {
    @EnvironmentObject var wellnessPlanViewModel: WellnessPlanViewModel
    @State private var showPopup: Bool = false
    @State private var popupMessage: String = ""
    @State private var loadingMessage: String = "Brewing your wellness potion... 🧪"
    @State private var currentDayPlan: DayPlan?

    let timeSlots = ["Morning", "Afternoon", "Evening", "Night"]
    let loadingMessages = [
        "Consulting the wellness wizards... 🧙‍♂️",
        "Summoning positive vibes... ✨",
        "Crafting your happiness blueprint... 📜",
        "Sprinkling motivation dust... 🌟",
        "Aligning your chakras... 🧘‍♀️",
        "Polishing your inner shine... ✨",
        "Tuning your wellness frequency... 📻",
        "Brewing your wellness potion... 🧪"
    ]

    var body: some View {
        Group {
            if wellnessPlanViewModel.isLoading || currentDayPlan == nil {
                VStack {
                    ProgressView(loadingMessage)
                        .padding()
                    Text("This might take a moment. We're making sure your plan is perfect!")
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .onAppear {
                    startLoadingAnimation()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Day \(wellnessPlanViewModel.currentDay) of 14")
                            .font(.headline)
                        Text("\(wellnessPlanViewModel.daysRemaining) days remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ForEach(timeSlots, id: \.self) { timeSlot in
                            let activities = currentDayPlan?.activities.filter { $0.timeSlot.lowercased() == timeSlot.lowercased() } ?? []
                            if !activities.isEmpty {
                                Section(header: Text(timeSlot).font(.headline)) {
                                    ForEach(activities) { activity in
                                        ActivityRowView(activity: activity) {
                                            completeActivity(activity)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadDailyPlan()
        }
        .overlay(
            PopupView(message: popupMessage, isPresented: $showPopup)
        )
        .navigationBarTitle("Daily Wellness Plan", displayMode: .inline)
    }

    private func startLoadingAnimation() {
        func updateLoadingMessage() {
            loadingMessage = loadingMessages.randomElement() ?? loadingMessages[0]
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if wellnessPlanViewModel.isLoading || currentDayPlan == nil {
                    updateLoadingMessage()
                }
            }
        }
        updateLoadingMessage()
    }

    private func loadDailyPlan() {
        if wellnessPlanViewModel.isUserAuthenticated, let userID = Auth.auth().currentUser?.uid {
            wellnessPlanViewModel.loadCurrentDayPlan { dayPlan in
                self.currentDayPlan = dayPlan
                if self.currentDayPlan == nil {
                    wellnessPlanViewModel.generateNewPlan(userID: userID) {
                        self.loadDailyPlan()
                    }
                }
            }
        } else {
            print("User is not authenticated")
        }
    }

    private func completeActivity(_ activity: Activity) {
        if let index = currentDayPlan?.activities.firstIndex(where: { $0.id == activity.id }) {
            // Toggle the completion status immediately in the UI
            currentDayPlan?.activities[index].isCompleted.toggle()
            
            // Update the ViewModel and Firebase
            let isCompleted = wellnessPlanViewModel.toggleActivityCompletion(activity)
            
            if isCompleted {
                showPopup = true
                popupMessage = "Well done! 😉+1"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showPopup = false
                }
            }
            
            // Refresh the plan after a short delay to ensure Firebase update is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadDailyPlan()
            }
        }
    }
}
