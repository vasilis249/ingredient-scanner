import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = URL(string: "http://localhost:8000")!

    func fetchAnalysis(for barcode: String) async throws -> ProductAnalysis {
        var components = URLComponents(url: baseURL.appendingPathComponent("analyze"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "barcode", value: barcode)]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid server response.")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unexpected server error."
            throw APIError.serverError(message)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(ProductAnalysis.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}
