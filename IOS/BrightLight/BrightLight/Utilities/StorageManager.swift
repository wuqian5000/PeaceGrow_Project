import Foundation
import CryptoKit

class StorageManager {
    static let shared = StorageManager()

    private let symmetricKey = SymmetricKey(size: .bits256) // You should securely store this key
    
    func securelyStorePlan(_ plan: [String: [Activity]]) throws {
        do {
            let encodedPlan = try JSONEncoder().encode(plan)
            let encryptedPlan = try AES.GCM.seal(encodedPlan, using: symmetricKey)
            UserDefaults.standard.set(encryptedPlan.combined, forKey: "encryptedPlan")
        } catch {
            throw NSError(domain: "Data encryption error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encrypt and store the plan."])
        }
    }
    
    func retrieveStoredPlan() throws -> [String: [Activity]] {
        guard let encryptedData = UserDefaults.standard.data(forKey: "encryptedPlan") else {
            throw NSError(domain: "Data retrieval error", code: -1, userInfo: [NSLocalizedDescriptionKey: "No encrypted plan found in storage."])
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            let plan = try JSONDecoder().decode([String: [Activity]].self, from: decryptedData)
            return plan
        } catch {
            throw NSError(domain: "Data decryption error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decrypt the stored plan."])
        }
    }
}
