import Foundation

/// Simple HTTP client for GET requests.
struct NetworkClient {
  /// Perform a GET request, returning the raw Data or an Error.
  static func get(from url: URL,
                  timeout: TimeInterval = 15,
                  completion: @escaping (Result<Data, Error>) -> Void) {
    var request = URLRequest(url: url,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: timeout)
    request.httpMethod = "GET"
    // Add any default headers here if you need them
    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        ARLog.debug("Network error: \(error.localizedDescription)")
        completion(.failure(error))
      } else if let http = response as? HTTPURLResponse,
                !(200...299).contains(http.statusCode) {
        ARLog.debug("HTTP error: \(http.statusCode)")
        completion(.failure(NSError(
          domain: "NetworkClient",
          code: http.statusCode,
          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
        )))
      } else if let data = data {
        ARLog.debug("Request successful, received \(data.count) bytes")
        completion(.success(data))
      } else {
        ARLog.debug("No data received")
        completion(.failure(NSError(
          domain: "NetworkClient",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "No data"]
        )))
      }
    }.resume()
  }
} 