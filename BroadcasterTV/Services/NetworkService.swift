import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to parse server response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        }
    }
}

actor NetworkService {
    static let shared = NetworkService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func fetchManifest(from config: ServerConfig) async throws -> ChannelManifest {
        guard let url = config.manifestURL() else {
            throw NetworkError.invalidURL
        }

        return try await fetch(url: url)
    }

    func fetchGuide(from config: ServerConfig) async throws -> GuideData {
        guard let url = config.guideURL() else {
            throw NetworkError.invalidURL
        }

        return try await fetch(url: url)
    }

    func validateConnection(config: ServerConfig) async throws -> Bool {
        guard let url = config.manifestURL() else {
            throw NetworkError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        let manifest = try JSONDecoder().decode(ChannelManifest.self, from: data)
        return !manifest.channels.isEmpty
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}
