import SwiftUI

struct TwoWeekCheckView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var currentQuestionIndex: Int = 0
    @State private var answers: [Int] = Array(repeating: 0, count: 10)
    @State private var showSummary: Bool = false
    @State private var showIntroduction: Bool = true
    @State private var showResults: Bool = false
    @State private var selectedAnswer: Int?
    @Binding var checkCompleted: Bool
    @State private var navigateToDailyWellnessPlan = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    let questions = [
        "How often have you felt nervous, anxious, or on edge?",
        "How often have you had trouble controlling your worry?",
        "How often have you found it difficult to relax?",
        "How often have you been so restless it's hard to sit still?",
        "How often have you felt afraid that something bad might happen?",
        "How often have you felt little interest or pleasure in doing things?",
        "How often have you felt down, depressed, or hopeless?",
        "How often have you had trouble falling or staying asleep, or sleeping too much?",
        "How often have you felt tired or had little energy?",
        "How often have you felt bad about yourself or that you are a failure?"
    ]

    var body: some View {
        VStack {
            if showResults || showSummary {
                summaryView()
            } else if showIntroduction {
                introductionView()
            } else {
                questionsView()
            }
        }
        .navigationBarTitle("Two-Week Wellness Check", displayMode: .inline)
        .onAppear {
            if viewModel.currentUser == nil {
                    // User is not authenticated, handle this case (e.g., show an alert or redirect to login)
                    print("Error: User is not authenticated")
                    return
            }
            checkForExistingResults()
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .background(
            NavigationLink(destination: DailyWellnessPlanView(), isActive: $navigateToDailyWellnessPlan) {
                EmptyView()
            }
        )
    }

    private func introductionView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Image("chatbot_profile_image")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                
                Text("Hi \(viewModel.currentUser?.fullname.split(separator: " ").first ?? "User"), in order to better support you and enhance your mental well-being, I'd like to ask you 10 quick questions about how you've been feeling over the past two weeks. Your answers will help us understand your needs more clearly and provide the best possible assistance. This will only take a few minutes, and your responses will remain completely confidential. Thank you for your cooperation and trust. 🌼")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Button(action: {
                showIntroduction = false
            }) {
                Text("I am ready, Let's do it.")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func questionsView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(questions[currentQuestionIndex])
                .font(.title2)
                .padding()
            
            VStack(spacing: 10) {
                ForEach(1...4, id: \.self) { score in
                    Button(action: {
                        selectAnswer(score)
                    }) {
                        Text(answerText(for: score))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(answers[currentQuestionIndex] == score ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            
            HStack {
                Spacer()
                HStack(spacing: 20) {
                    Button("Previous") {
                        previousQuestion()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .opacity(currentQuestionIndex > 0 ? 1 : 0)
                    .disabled(currentQuestionIndex == 0)
                    
                    Button(currentQuestionIndex == questions.count - 1 ? "Submit" : "Next") {
                        nextQuestion()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .opacity(answers[currentQuestionIndex] != 0 ? 1 : 0)
                    .disabled(answers[currentQuestionIndex] == 0)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding()
                .frame(width: 120) // Fixed width for both buttons
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
        }
    }
    
    private func previousQuestion() {
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
            selectedAnswer = answers[currentQuestionIndex]
        }
    }

    private func summaryView() -> some View {
        VStack {
            Text("Your Results")
                .font(.title)
                .padding()
            Text("Anxiety Level: \(getGADScoreLevel())")
            Text("Depression Level: \(getPHQScoreLevel())")
            Text(getSummary())
            NavigationLink(destination: DailyWellnessPlanView()) {
                Button("Let's work it out") 
                {
                    navigateToDailyWellnessPlan = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }

    private func selectAnswer(_ score: Int) {
        answers[currentQuestionIndex] = score
    }

    private func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            saveResults()
            showSummary = true
        }
    }

    private func answerText(for score: Int) -> String {
        switch score {
        case 1: return "Not at all"
        case 2: return "Several days"
        case 3: return "More than half the days"
        case 4: return "Nearly every day"
        default: return ""
        }
    }

    private func checkForExistingResults() {
        guard let userID = viewModel.currentUser?.id else { return }
        
        FirestoreManager.shared.fetchLatestTwoWeekCheck(userID: userID) { date, gadScore, gadScoreLevel, phqScore, phqScoreLevel in
            DispatchQueue.main.async {
                if let date = date {
                    let calendar = Calendar.current
                    let daysSinceLastCheck = calendar.dateComponents([.day], from: date.dateValue(), to: Date()).day ?? 0
                    
                    if daysSinceLastCheck < 14 {
                        self.answers = self.reconstructAnswers(gadScore: gadScore ?? 0, phqScore: phqScore ?? 0)
                        self.showResults = true
                    } else {
                        self.showIntroduction = true
                    }
                } else {
                    self.showIntroduction = true
                }
            }
        }
    }

    private func reconstructAnswers(gadScore: Int, phqScore: Int) -> [Int] {
        var reconstructedAnswers = Array(repeating: 0, count: 10)
        
        for i in 0..<5 {
            reconstructedAnswers[i] = min(4, max(1, gadScore / 5))
        }
        
        for i in 5..<10 {
            reconstructedAnswers[i] = min(4, max(1, phqScore / 5))
        }
        
        return reconstructedAnswers
    }

    private func getGADScoreLevel() -> String {
        let gadScore = answers.prefix(5).reduce(0, +)
        switch gadScore {
        case 0...5: return "Minimal Anxiety"
        case 6...10: return "Mild Anxiety"
        case 11...15: return "Moderate Anxiety"
        case 16...20: return "Severe Anxiety"
        default: return "Unknown"
        }
    }

    private func getPHQScoreLevel() -> String {
        let phqScore = answers.suffix(5).reduce(0, +)
        switch phqScore {
        case 0...5: return "Minimal Depression"
        case 6...10: return "Mild Depression"
        case 11...15: return "Moderate Depression"
        case 16...20: return "Severe Depression"
        default: return "Unknown"
        }
    }

    private func getSummary() -> String {
        let gadScoreLevel = getGADScoreLevel()
        let phqScoreLevel = getPHQScoreLevel()
        var summary = ""

        switch gadScoreLevel {
        case "Minimal Anxiety":
            summary += "Your anxiety levels are minimal. It's great that you're experiencing low anxiety! Continue practicing good habits to maintain your well-being."
        case "Mild Anxiety":
            summary += "You have mild anxiety, which can be managed with some focused self-care. Let's explore simple techniques to help you stay calm."
        case "Moderate Anxiety":
            summary += "Your anxiety levels are moderate, indicating a need for more structured support. We can work on strategies to manage your anxiety effectively."
        case "Severe Anxiety":
            summary += "You're experiencing severe anxiety, and it's important to seek professional help. Let's make sure you have access to the necessary support."
        default:
            break
        }

        summary += "\n\n"

        switch phqScoreLevel {
        case "Minimal Depression":
            summary += "Your depression levels are minimal. It's wonderful that you're feeling good. Keep up the positive lifestyle choices."
        case "Mild Depression":
            summary += "You have mild depression, which can be addressed with some targeted self-care strategies. Let's find ways to uplift your mood."
        case "Moderate Depression":
            summary += "Your depression is moderate, indicating that you could benefit from more structured help. We can focus on improving your mood together."
        case "Severe Depression":
            summary += "You're experiencing severe depression, and it's important to seek professional help. Let's make sure you have access to the necessary support."
        default:
            break
        }

        return summary
    }

    private func saveResults(){
        
        guard let userID = viewModel.currentUser?.id, !userID.isEmpty else {
                print("Error: Invalid or empty user ID")
                // Show an alert to the user
                return
            }
        let gadScore = answers.prefix(5).reduce(0, +)
        let phqScore = answers.suffix(5).reduce(0, +)
        let gadScoreLevel = getGADScoreLevel()
        let phqScoreLevel = getPHQScoreLevel()

        FirestoreManager.shared.storeTwoWeekCheckAndGeneratePlan(
            userID: viewModel.currentUser?.id ?? "",
            gadScore: gadScore,
            gadScoreLevel: gadScoreLevel,
            phqScore: phqScore,
            phqScoreLevel: phqScoreLevel
        ) { error in
            if let error = error {
                print("Error saving results and generating plan: \(error.localizedDescription)")
                // Show an alert to the user
                DispatchQueue.main.async {
                        self.errorMessage = "Failed to save results. Please try again."
                        self.showErrorAlert = true
                    }
            } else {
                print("Results saved and plan generated successfully.")
                DispatchQueue.main.async {
                    self.checkCompleted = true
                    self.showSummary = true
                }
            }
        }
    }
}
