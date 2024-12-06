import Foundation

class EmotionAnalysisService {
    static let shared = EmotionAnalysisService()
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 20 // seconds

    func analyzeEmotion(for text: String, completion: @escaping ([String: Double]) -> Void) {
        analyzeEmotion(for: text, retries: maxRetries, completion: completion)
    }

    private func analyzeEmotion(for text: String, retries: Int, completion: @escaping ([String: Double]) -> Void) {
        guard let url = URL(string: "https://api-inference.huggingface.co/models/SamLowe/roberta-base-go_emotions") else {
            completion([:])
            return
        }

        let parameters: [String: Any] = ["inputs": text]
        guard let body = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            completion([:])
            return
        }

        APIClient.shared.sendRequest(to: url, method: "POST", body: body, apiType: .huggingFace) { result in
            switch result {
            case .success(let data):
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Full API Response: \(jsonString)")
                }
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let error = json["error"] as? String, error.contains("currently loading") {
                    if retries > 0 {
                        print("Model is loading, retrying in \(self.retryDelay) seconds...")
                        DispatchQueue.global().asyncAfter(deadline: .now() + self.retryDelay) {
                            self.analyzeEmotion(for: text, retries: retries - 1, completion: completion)
                        }
                    } else {
                        print("Model loading timeout, giving up.")
                        completion([:])
                    }
                } else {
                    let emotionScores = self.parseEmotionScores(from: data)
                    print("Emotion scores: \(emotionScores)")
                    completion(emotionScores)
                }
            case .failure(let error):
                print("Error analyzing emotion: \(error.localizedDescription)")
                completion([:])
            }
        }
    }

    private func parseEmotionScores(from data: Data) -> [String: Double] {
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[Any]],
               let firstResult = jsonArray.first as? [[String: Any]] {
                var scores: [String: Double] = [:]
                for emotionDict in firstResult {
                    if let label = emotionDict["label"] as? String, let score = emotionDict["score"] as? Double {
                        scores[label] = score
                    }
                }
                return scores
            }
        } catch {
            print("Error parsing emotion scores: \(error.localizedDescription)")
        }
        return [:]
    }
}
