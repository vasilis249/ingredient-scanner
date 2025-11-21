import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    /// Update this base URL to point to your deployed backend.
    private let baseURL = URL(string: "http://127.0.0.1:8000")!

    func analyzeCosmetic(barcode: String) async throws -> ProductAnalysisResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("cosmetics/analyze"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "barcode", value: barcode)]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return try decodeResponse(data: data, response: response)
        } catch let urlError as URLError {
            throw APIError.serverError(urlError.localizedDescription)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.serverError("Unexpected error: \(error.localizedDescription)")
        }
    }

    private func decodeResponse(data: Data, response: URLResponse) throws -> ProductAnalysisResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid server response.")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw decodeServerError(data: data, statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(ProductAnalysisResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func decodeServerError(data: Data, statusCode: Int) -> APIError {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = json["detail"] as? String {
                return .serverError(detail)
            }
            if let message = json["message"] as? String {
                return .serverError(message)
            }
        }

        let fallback = String(data: data, encoding: .utf8) ?? "Server error (status: \(statusCode))."
        return .serverError(fallback)
    }
}
