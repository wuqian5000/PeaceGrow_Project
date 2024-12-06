import Foundation

class OpenAIService {
    static let shared = OpenAIService() // Singleton instance
    private let apiClient = APIClient.shared
    private let cache = NSCache<NSString, NSString>()
    private let maxRetries = 3

    private init() {}

    func getResponse(for prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        getResponseWithRetry(for: prompt, retries: maxRetries, completion: completion)
    }

    private func getResponseWithRetry(for prompt: String, retries: Int, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(NSError(domain: "OpenAIService", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        let parameters: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": prompt]
            ]
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: parameters) else {
            completion(.failure(NSError(domain: "OpenAIService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])))
            return
        }

        apiClient.sendRequest(to: url, method: "POST", body: body, apiType: .openAI) { result in
            switch result {
            case .success(let data):
                self.handleAPIResponse(data: data, prompt: prompt, retries: retries, completion: completion)
            case .failure(let error):
                self.handleAPIError(error: error, prompt: prompt, retries: retries, completion: completion)
            }
        }
    }

    private func handleAPIResponse(data: Data, prompt: String, retries: Int, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                self.handleAPIError(error: NSError(domain: "OpenAIService", code: 1002, userInfo: [NSLocalizedDescriptionKey: errorResponse.error.message]), prompt: prompt, retries: retries, completion: completion)
                return
            }

            let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            let content = response.choices.first?.message.content ?? ""
            self.cache.setObject(NSString(string: content), forKey: NSString(string: prompt))
            completion(.success(content))
        } catch {
            self.handleAPIError(error: error, prompt: prompt, retries: retries, completion: completion)
        }
    }

    private func handleAPIError(error: Error, prompt: String, retries: Int, completion: @escaping (Result<String, Error>) -> Void) {
        if retries > 0 {
            print("Retrying API call. Attempts left: \(retries - 1)")
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                self.getResponseWithRetry(for: prompt, retries: retries - 1, completion: completion)
            }
        } else {
            completion(.failure(error))
        }
    }

    func getResponses(for prompt: String, completion: @escaping (Result<[String], Error>) -> Void) {
        getResponse(for: prompt) { result in
            switch result {
            case .success(let response):
                let messages = [response] // Since we're only getting one response now
                completion(.success(messages))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func summarizeText(from text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = "Summarize the following text in no more than 15 words:\n\n\(text)\n\nSummary:"
        getResponse(for: prompt, completion: completion)
    }

    func generate14DayPlan(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        generatePartialPlan(prompt: prompt, days: 1...14) { result in
            switch result {
            case .success(let fullPlan):
                completion(.success(fullPlan))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func generatePartialPlan(prompt: String, days: ClosedRange<Int>, completion: @escaping (Result<String, Error>) -> Void) {
        let daysString = days.map { "Day \($0)" }.joined(separator: ", ")
        let enhancedPrompt = """
        Generate a detailed wellness plan for the following days: \(daysString). Each day MUST include morning, afternoon, evening, and night activities. Format the plan as follows:

        Day X:
        Morning:
        - Activity Title (Duration): Description
        Afternoon:
        - Activity Title (Duration): Description
        Evening:
        - Activity Title (Duration): Description
        Night:
        - Activity Title (Duration): Description

        Additional requirements:
        \(prompt)
        """

        getResponse(for: enhancedPrompt) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                if self.validatePartialPlanStructure(response, days: days) {
                    if days.upperBound == 14 {
                        completion(.success(response))
                    } else {
                        let nextDays = (days.upperBound + 1)...14
                        self.generatePartialPlan(prompt: prompt, days: nextDays) { nextResult in
                            switch nextResult {
                            case .success(let nextResponse):
                                let fullPlan = response + "\n\n" + nextResponse
                                completion(.success(fullPlan))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    }
                } else {
                    self.retryGeneration(prompt: enhancedPrompt, days: days, completion: completion)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func retryGeneration(prompt: String, days: ClosedRange<Int>, completion: @escaping (Result<String, Error>) -> Void) {
            getResponse(for: prompt) { result in
                switch result {
                case .success(let response):
                    if self.validatePartialPlanStructure(response, days: days) {
                        completion(.success(response))
                    } else {
                        completion(.failure(NSError(domain: "OpenAIService", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Failed to generate valid plan structure after retry"])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

    private func validatePartialPlanStructure(_ plan: String, days: ClosedRange<Int>) -> Bool {
        let requiredElements = days.map { "Day \($0):" } + ["Morning:", "Afternoon:", "Evening:", "Night:"]
        return requiredElements.allSatisfy { plan.contains($0) }
    }

}

struct OpenAIChatResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
    }
    
    struct Message: Decodable {
        let content: String
    }
}

struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
    
    struct OpenAIError: Decodable {
        let message: String
        let type: String
        let param: String?
        let code: String?
    }
}
