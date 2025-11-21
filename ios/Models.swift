import Foundation

struct IngredientRisk: Identifiable, Codable {
    let id: UUID = UUID()
    let inciName: String
    let function: String
    let origin: String?
    let riskLevel: String
    let concerns: [String]
    let aiSummary: String
}

struct ProductAnalysisResponse: Codable {
    let productName: String
    let barcode: String
    let ingredients: [IngredientRisk]
    let overallScore: String
    let overallSummary: String
    let disclaimer: String
}

enum APIError: LocalizedError {
    case invalidURL
    case decodingFailed
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The service URL is invalid."
        case .decodingFailed:
            return "Unable to decode the response."
        case .serverError(let message):
            return message
        }
    }
}
