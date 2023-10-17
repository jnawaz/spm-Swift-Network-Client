//
//  WebServiceConfiguration.swift
//
//
//  Created by Jamil Nawaz on 17/10/2023.
//

import Foundation

public enum WebServiceResult<R> {
    case success(R)
    case failure(Error)
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public enum ContentType: String {
    case json = "application/json"
    case multipartForm = "multipart/form-data"
}

public protocol WebServiceConfiguration {
    associatedtype Response: Decodable

    var baseUrl: URL { get set }
    var method: HTTPMethod {get}
    var pathComponents: [String] {get}
    var queryParameters: [URLQueryItem]? { get }
    var networkManager: NetworkManager { get }
}

extension WebServiceConfiguration {
    var networkManager: NetworkManager {
        return NetworkManager()
    }
}

// MARK: Default configuration
 extension WebServiceConfiguration {
    var baseUrl: URL { return URL(string: "")! }
    var method: HTTPMethod { .get }
    var queryParameters: [URLQueryItem]? { return nil }

    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func configurationError(from statusCode: Int) throws {}

    func decodeResponse(data: Data) throws -> Response {
        return try decoder.decode(Response.self, from: data)
    }
}

// MARK: Request Execution
extension WebServiceConfiguration {
    public func start(completion: @escaping (WebServiceResult<Response>) -> Void) {

        let request = createRequest()

        networkManager.request(request) { (data, response, error) in

            let parsedResponse = self.parseResponse(data: data, response: response, error: error)

            DispatchQueue.main.sync {
                completion(parsedResponse)
            }
        }

    }

    private func createRequest() -> URLRequest {

        var url = baseUrl

        for component in pathComponents {
            url = url.appendingPathComponent(component)
        }

        //add query parameters
        if let queryParameters = queryParameters, !queryParameters.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            components.queryItems = queryParameters
            url = components.url!
        }

        //create request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue

        return urlRequest
    }

    private func parseResponse(data: Data?, response: URLResponse?, error: Error?) -> WebServiceResult<Response> {

        //handle errors
        if let error = error as NSError? {

            if error.code == NSURLErrorNotConnectedToInternet {
                return .failure(WebServiceError.noInternetError)
            }

            if error.code == NSURLErrorCancelled {
                return .failure(WebServiceError.cancelled)
            }

            return .failure(WebServiceError.networkingError)
        }

        do {
            //validate status code
            guard let statusCode = response?.httpStatusCode else {
                return .failure(WebServiceError.invalidResponse(debugDescription: "Failed to parse HTTP status code"))
            }

            try validate(statusCode)

            guard let data = data else {
                return .failure(WebServiceError.invalidResponse(debugDescription: "Response data was nil"))
            }

            let parsedResponse = try decodeResponse(data: data)
            return .success(parsedResponse)

        } catch let requestError as WebServiceError {
            return .failure(requestError)
        } catch {
            return .failure(WebServiceError.invalidResponse(debugDescription: "\(error)"))
        }
    }

    private func validate(_ statusCode: Int) throws {
        guard statusCode >= 200 && statusCode < 300 else {

            //check for configuration specific error
            try configurationError(from: statusCode)

            switch statusCode {
            case 400:
                throw WebServiceError.badRequest
            case 401:
                throw WebServiceError.unauthorisedError
            case 403:
                throw WebServiceError.forbidden
            case 404:
                throw WebServiceError.notFound
            case 409:
                throw WebServiceError.conflict
            default:
                throw WebServiceError.badResponse(statusCode: statusCode)
            }
        }
    }
}

extension URLResponse {

    var httpStatusCode: Int? {

        guard let httpResponse = self as? HTTPURLResponse else {
            return nil
        }

        return httpResponse.statusCode

    }
}
