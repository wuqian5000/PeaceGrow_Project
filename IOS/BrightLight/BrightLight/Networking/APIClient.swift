import Foundation

class APIClient {
    static let shared = APIClient()
    private init() {}

    enum APIType {
        case openAI
        case huggingFace
    }

    func sendRequest(to url: URL, method: String, body: Data?, apiType: APIType, completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        switch apiType {
        case .openAI:
            let apiKey = Config.openAIAPIKey
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .huggingFace:
            let apiKey = Config.huggingFaceAPIKey
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])
                completion(.failure(error))
                return
            }

            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw API Response: \(responseString)")
            }

            completion(.success(data))
        }

        task.resume()
    }
}
