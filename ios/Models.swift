import Foundation

struct IngredientAnalysis: Identifiable, Codable {
    let id: UUID = UUID()
    let name: String
    let risk: String
    let details: String
}

struct ProductAnalysis: Codable {
    let productName: String
    let ingredients: [IngredientAnalysis]
    let overallScore: String
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
