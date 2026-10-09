import Foundation

/// Ошибки сети. UI не показывает их как аварию: без сети приложение продолжает работать (ARCHITECTURE.md, раздел 11).
enum APIError: Error, Equatable, Sendable {
    case invalidResponse
    case notFound
    case httpStatus(Int)
    case timeout
    case transport
}

/// Минимальный HTTP-клиент с таймаутом. Статус-коды и тайм-ауты проверяются здесь, а не в провайдерах.
struct APIClient: Sendable {
    let session: URLSession
    let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 10) {
        self.session = session
        self.timeout = timeout
    }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            switch http.statusCode {
            case 200..<300:
                return data
            case 404:
                throw APIError.notFound
            default:
                throw APIError.httpStatus(http.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.transport
        }
    }
}
