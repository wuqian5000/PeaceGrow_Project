import Firebase
import FirebaseAuth
import FirebaseFirestore
import Foundation

class FirestoreManager {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    private let openAIService = OpenAIService.shared

    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    func storeTwoWeekCheckAndGeneratePlan(userID: String, gadScore: Int, gadScoreLevel: String, phqScore: Int, phqScoreLevel: String, completion: @escaping (Error?) -> Void) {
        guard !userID.isEmpty else {
            completion(NSError(domain: "FirestoreManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID is empty"]))
            return
        }
        let checkData: [String: Any] = [
            "date": Timestamp(date: Date()),
            "gadScore": gadScore,
            "gadScoreLevel": gadScoreLevel,
            "phqScore": phqScore,
            "phqScoreLevel": phqScoreLevel
        ]

        db.collection("users").document(userID).collection("twoweek_check_records").addDocument(data: checkData) { [weak self] error in
            if let error = error {
                print("Error adding two-week check document: \(error)")
                completion(error)
            } else {
                print("Two-week check document added successfully")
                self?.generateAndStorePlan(userID: userID, gadScore: gadScore, phqScore: phqScore, completion: completion)
            }
        }
    }

    private func generateAndStorePlan(userID: String, gadScore: Int, phqScore: Int, completion: @escaping (Error?) -> Void) {
        fetchUserPreferences(userID: userID) { [weak self] preferences in
            guard let self = self else { return }
            self.generatePlanWithAI(gadScore: gadScore, phqScore: phqScore, preferences: preferences) { result in
                switch result {
                case .success(let plan):
                    self.savePlanToFirebase(userID: userID, plan: plan) { error in
                        if let error = error {
                            print("Error saving plan to Firebase: \(error.localizedDescription)")
                        } else {
                            print("Plan successfully saved to Firebase")
                        }
                        completion(error)
                    }
                case .failure(let error):
                    print("Error generating plan: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }

    private func fetchUserPreferences(userID: String, completion: @escaping ([String: Double]) -> Void) {
        let docRef = db.collection("users").document(userID).collection("preference_scores").document("latest")
        
        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data() ?? [:]
                let scores = data.mapValues { $0 as? Double ?? 0.0 }
                completion(scores)
            } else {
                completion([:])
            }
        }
    }

    func generatePlanWithAI(gadScore: Int, phqScore: Int, preferences: [String: Double], completion: @escaping (Result<[DayPlan], Error>) -> Void) {
        let prompt = createPrompt(gadScore: gadScore, phqScore: phqScore, preferences: preferences)
        
        openAIService.generate14DayPlan(prompt: prompt) { result in
            switch result {
            case .success(let response):
                let plan = self.parsePlanFromAIResponse(response)
                if plan.count == 14 {
                    completion(.success(plan))
                } else {
                    completion(.failure(NSError(domain: "FirestoreManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Generated plan does not have 14 days"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func createPrompt(gadScore: Int, phqScore: Int, preferences: [String: Double]) -> String {
        let topPreferences = preferences.sorted { $0.value > $1.value }.prefix(5)
        let preferencesString = topPreferences.map { "\($0.key): \(String(format: "%.1f", $0.value))%" }.joined(separator: ", ")
        
        return """
        As Bryan, a compassionate and caring wellness guide, create a personalized 14-day wellness plan for a user with the following characteristics:

        GAD-7 score: \(gadScore)
        PHQ-9 score: \(phqScore)
        Top 5 activity preferences: \(preferencesString)

        Create a plan that addresses the user's anxiety and depression levels while incorporating their preferred activities. Include a mix of activities that address mental, emotional, and physical well-being, drawing inspiration from various therapeutic approaches like CBT, mindfulness, and person-centered therapy.

        For each day, provide one or two morning, afternoon, evening, and nighttime activities, each lasting within 30 minutes. These should be practical, engaging, and aimed at improving the user's overall wellness.

        Use language that is encouraging and empowering. Offer brief insights into why certain activities are beneficial, but do so in a natural, conversational manner. Maintain a balance between structure and flexibility, allowing the user to adapt the plan as needed. Encourage self-reflection and gentle self-awareness throughout the week.

        Important: Each activity description should be between 25 and 40 words long. This length allows for detailed, engaging descriptions while remaining concise.

        Format the plan as follows for each day:

        Day X:
        Morning:
        - Activity Title (Duration): Description (25-40 words)
        Afternoon:
        - Activity Title (Duration): Description (25-40 words)
        Evening:
        - Activity Title (Duration): Description (25-40 words)
        Night:
        - Activity Title (Duration): Description (25-40 words)

        Remember to use gentle emojis every few lines to maintain a warm and friendly tone. 🌸

        Ensure that each activity description is thoughtful, specific, and tailored to the user's needs, providing clear guidance and motivation within the 25-40 word limit.
        """
    }

    private func parsePlanFromAIResponse(_ response: String) -> [DayPlan] {
           var plans: [DayPlan] = []
           let dayStrings = response.components(separatedBy: "Day ")
           
           print("Number of day strings: \(dayStrings.count)")
           
           for dayString in dayStrings.dropFirst() {
               let dayComponents = dayString.components(separatedBy: "\n")
               guard let dayNumberString = dayComponents.first,
                     let dayNumber = Int(dayNumberString.trimmingCharacters(in: .punctuationCharacters)) else {
                   continue
               }
               
               print("Processing Day \(dayNumber)")
               
               var activities: [Activity] = []
               var currentTimeSlot = ""
               
               for line in dayComponents.dropFirst() {
                   if line.hasSuffix(":") {
                       currentTimeSlot = line.trimmingCharacters(in: .punctuationCharacters)
                   } else if line.starts(with: "- ") {
                       let activityComponents = line.dropFirst(2).components(separatedBy: ":")
                       guard activityComponents.count == 2 else { continue }
                       
                       let titleDuration = activityComponents[0].components(separatedBy: "(")
                       guard titleDuration.count == 2 else { continue }
                       
                       let title = titleDuration[0].trimmingCharacters(in: .whitespaces)
                       let durationString = titleDuration[1].trimmingCharacters(in: .punctuationCharacters)
                       let duration = Int(durationString.components(separatedBy: " ")[0]) ?? 30
                       let content = activityComponents[1].trimmingCharacters(in: .whitespaces)
                       
                       let activity = Activity(
                           title: title,
                           content: content,
                           duration: duration,
                           category: ActivityCategory.determineCategory(from: title),
                           isCompleted: false,
                           timeSlot: currentTimeSlot
                       )
                       activities.append(activity)
                   }
               }
               
               let dayPlan = DayPlan(dayNumber: dayNumber, activities: activities)
               plans.append(dayPlan)
           }
           
           print("Final number of days in plan: \(plans.count)")
           return plans
       }

    func savePlanToFirebase(userID: String, plan: [DayPlan], completion: @escaping (Error?) -> Void) {
        
        guard !plan.isEmpty else {
                completion(NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Plan is empty"]))
                return
            }
        
        let planData = plan.map { dayPlan in
            return [
                "dayNumber": dayPlan.dayNumber,
                "activities": dayPlan.activities.map { activity in
                    return [
                        "id": activity.id.uuidString,
                        "timeSlot": activity.timeSlot,
                        "duration": activity.duration,
                        "title": activity.title,
                        "content": activity.content,
                        "category": activity.category.rawValue,
                        "isCompleted": activity.isCompleted
                    ]
                }
            ]
        }

        let data: [String: Any] = [
            "creationDate": Timestamp(date: Date()),  // Include creation date
            "plan": planData
        ]

        db.collection("users").document(userID).collection("plans").document("currentPlan").setData(data) { error in
            if let error = error {
                print("Error storing plan: \(error)")
            } else {
                print("Plan stored successfully")
                self.cachePlanLocally(plan: plan, creationDate: Date())
            }
            completion(error)
        }
    }

    func cachePlanLocally(plan: [DayPlan], creationDate: Date) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(plan) {
            UserDefaults.standard.set(encoded, forKey: "cachedPlan")
            UserDefaults.standard.set(creationDate, forKey: "planCreationDate")  // Store creation date locally
        }
    }


    func loadCachedPlan() -> [DayPlan]? {
        if let data = UserDefaults.standard.data(forKey: "cachedPlan") {
            let decoder = JSONDecoder()
            if let plan = try? decoder.decode([DayPlan].self, from: data) {
                return plan
            }
        }
        return nil
    }

    func fetchCurrentPlan(userID: String, completion: @escaping ([DayPlan]?, Date?, Error?) -> Void) {
        
        let docRef = db.collection("users").document(userID).collection("plans").document("currentPlan")
        docRef.getDocument { (document, error) in
            if let error = error {
                completion(nil, nil, error)
                return
            }

            guard let document = document, document.exists,
                  let data = document.data(),
                  let planData = data["plan"] as? [[String: Any]],
                  let creationDate = data["creationDate"] as? Timestamp else {
                completion(nil, nil, NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Plan not found"]))
                return
            }

            let parsedPlan = planData.compactMap { dayData -> DayPlan? in
                guard let dayNumber = dayData["dayNumber"] as? Int,
                      let activitiesData = dayData["activities"] as? [[String: Any]] else {
                    return nil
                }

                let activities = activitiesData.compactMap { activityData -> Activity? in
                    guard let id = activityData["id"] as? String,
                          let title = activityData["title"] as? String,
                          let content = activityData["content"] as? String,
                          let duration = activityData["duration"] as? Int,
                          let categoryRawValue = activityData["category"] as? String,
                          let category = ActivityCategory(rawValue: categoryRawValue),
                          let timeSlot = activityData["timeSlot"] as? String,
                          let isCompleted = activityData["isCompleted"] as? Bool else {
                        return nil
                    }

                    return Activity(
                        id: UUID(uuidString: id) ?? UUID(),
                        title: title,
                        content: content,
                        duration: duration,
                        category: category,
                        isCompleted: isCompleted,
                        timeSlot: timeSlot
                    )
                }

                return DayPlan(dayNumber: dayNumber, activities: activities)
            }

            completion(parsedPlan, creationDate.dateValue(), nil)
        }
    }


    func fetchLatestTwoWeekCheck(userID: String, completion: @escaping (Timestamp?, Int?, String?, Int?, String?) -> Void) {
        guard !userID.isEmpty else {
            print("User ID is empty.")
            completion(nil, nil, nil, nil, nil)
            return
        }

        db.collection("users").document(userID).collection("twoweek_check_records")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching latest two-week check: \(error.localizedDescription)")
                    completion(nil, nil, nil, nil, nil)
                } else if let document = snapshot?.documents.first {
                    let data = document.data()
                    let date = data["date"] as? Timestamp
                    let gadScore = data["gadScore"] as? Int
                    let gadScoreLevel = data["gadScoreLevel"] as? String
                    let phqScore = data["phqScore"] as? Int
                    let phqScoreLevel = data["phqScoreLevel"] as? String
                    completion(date, gadScore, gadScoreLevel, phqScore, phqScoreLevel)
                } else {
                    print("No records found.")
                    completion(nil, nil, nil, nil, nil)
                }
            }
    }
    
    func fetchPreferenceScores(userID: String, completion: @escaping ([String: Double]) -> Void) {
            let docRef = db.collection("users").document(userID).collection("preference_scores").document("latest")
            
            docRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    let data = document.data() ?? [:]
                    let scores = data.mapValues { $0 as? Double ?? 0.0 }
                    completion(scores)
                } else {
                    completion([:])
                }
            }
        }

    func updatePreferenceScores(userID: String, activity: String, score: Double) {
            let docRef = db.collection("users").document(userID).collection("preference_scores").document("latest")
            
            docRef.setData([activity: score], merge: true) { error in
                if let error = error {
                    print("Error updating preference score: \(error.localizedDescription)")
                } else {
                    print("Preference score for \(activity) updated successfully")
                }
            }
        }
    
    func updatePlanInFirebase(userID: String, plan: [DayPlan], completion: @escaping (Error?) -> Void) {
        let docRef = db.collection("users").document(userID).collection("plans").document("currentPlan")
        
        docRef.getDocument { (document, error) in
            if let error = error {
                completion(error)
                return
            }
            
            guard let document = document, document.exists else {
                completion(NSError(domain: "FirestoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Plan not found"]))
                return
            }
            
            let existingData = document.data() ?? [:]
            let creationDate = existingData["creationDate"] as? Timestamp ?? Timestamp(date: Date())
            
            let planData = plan.map { dayPlan -> [String: Any] in
                return [
                    "dayNumber": dayPlan.dayNumber,
                    "activities": dayPlan.activities.map { activity -> [String: Any] in
                        return [
                            "id": activity.id.uuidString,
                            "title": activity.title,
                            "content": activity.content,
                            "duration": activity.duration,
                            "category": activity.category.rawValue,
                            "timeSlot": activity.timeSlot,
                            "isCompleted": activity.isCompleted
                        ]
                    }
                ]
            }
            
            let updatedData: [String: Any] = [
                "creationDate": creationDate,
                "plan": planData
            ]
            
            docRef.setData(updatedData) { error in
                if let error = error {
                    print("Error updating plan in Firebase: \(error.localizedDescription)")
                    completion(error)
                } else {
                    print("Plan updated successfully in Firebase")
                    completion(nil)
                }
            }
        }
    }
    
    func storeDailyEmotions(userID: String, emotions: [Emotion], summary: String, greetingTexts: [String], completion: @escaping (Error?) -> Void) {
        let data: [String: Any] = [
            "date": Timestamp(date: Date()),
            "emotions": emotions.map { $0.name },
            "emotions_values": emotions.map { $0.value },
            "summary": summary,
            "greeting_texts": greetingTexts.enumerated().reduce(into: [String: String]()) { $0["\($1.offset)"] = $1.element }
        ]

        db.collection("users").document(userID).collection("daily_emotions").addDocument(data: data) { error in
            if let error = error {
                print("Error adding document: \(error)")
            } else {
                print("Document added with data: \(data)")
            }
            completion(error)
        }
    }

    func fetchLatestSummary(userID: String, completion: @escaping (String?) -> Void) {
        db.collection("users").document(userID).collection("daily_emotions")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching summary: \(error.localizedDescription)")
                    completion(nil)
                } else if let document = snapshot?.documents.first,
                          let summary = document.data()["summary"] as? String {
                    completion(summary)
                } else {
                    completion(nil)
                }
            }
    }
}
