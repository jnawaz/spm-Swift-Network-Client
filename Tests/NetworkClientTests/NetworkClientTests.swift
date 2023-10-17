import XCTest
@testable import NetworkClient

final class NetworkClientTests: XCTestCase {
    private let failureExpectation = "This should have failed to be a success"
    private let expectedFailureForOtherReason = "This should have failed for a different reason"
    private let testTimeout = 5.0
    private let testExpectation = XCTestExpectation()
    private let decodingError = "typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [_JSONKey(stringValue: \"Index 0\", intValue: 0)], debugDescription: \"Expected to decode String but found a number instead.\", underlyingError: nil))"

    struct ExampleWebServiceConfiguration: WebServiceConfiguration {

        typealias Response = [String]
        var baseUrl: URL = URL(string: "https://www.google.com")!
        let query: String
        let method: HTTPMethod = .post
        let networkManager: NetworkManager
        var pathComponents: [String] {
            return ["test", query]
        }
    }

    func generateExampleWebServiceConfiguration(query: String = "someQuery") -> (webServiceConfiguration: ExampleWebServiceConfiguration, mock: URLSessionMock) {
        let mock = URLSessionMock()
        let networkManager = NetworkManager(session: mock)
        return (ExampleWebServiceConfiguration(query: query, networkManager: networkManager), mock)
    }

    // MARK: - Request
    func testsRequestSetupCorrectly() {
        let (sut, mock) = generateExampleWebServiceConfiguration()

        mock.willRequest = { request in
            guard let urlString = request.url?.absoluteString
                    else {
                return
            }

            sut.pathComponents.forEach {
                XCTAssertTrue(urlString.contains($0))
            }

            XCTAssertEqual(request.httpMethod, sut.method.rawValue)
        }

        sut.start { _ in
        }
    }

    // MARK: - Errors
    func testHandlesConnectionError() {
        let (sut, mock) = generateExampleWebServiceConfiguration()
        mock.error = NSError(domain: "", code: NSURLErrorNotConnectedToInternet, userInfo: nil)

        sut.start { response in
            switch response {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .noInternetError)
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }

        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }

    func testHandlesCancelledError() {
        let (sut, mock) = generateExampleWebServiceConfiguration()
        mock.error = NSError(domain: "", code: NSURLErrorCancelled, userInfo: nil)

        sut.start { response in
            switch response {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .cancelled)
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }
        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }

    func testHandlesUnknownError() {
        let (sut, mock) = generateExampleWebServiceConfiguration()
        mock.error = NSError(domain: "", code: NSURLErrorUnknown, userInfo: nil)

        sut.start { response in
            switch response {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .networkingError)
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }

        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }

    // MARK: - Invalid responses
    func testHandlesNoStatusCode() {
        let (sut, _) = generateExampleWebServiceConfiguration()

        sut.start { responseType in
            switch responseType {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .invalidResponse(debugDescription: "Failed to parse HTTP status code"))
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }

        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }

    func testHandlesNoData() {
        let (sut, mock) = generateExampleWebServiceConfiguration()

        let response = HTTPURLResponse(url: sut.baseUrl, statusCode: 200, httpVersion: nil, headerFields: nil)
        mock.response = response

        sut.start { response in
            switch response {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .invalidResponse(debugDescription: "Response data was nil"))
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }

        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }

    // MARK: - 400 Errors
    func testHandles400StatusCode() {
        let (sut, mock) = generateExampleWebServiceConfiguration()

        let response = HTTPURLResponse(url: sut.baseUrl, statusCode: 400, httpVersion: nil, headerFields: nil)
        mock.response = response

        sut.start { response in
            switch response {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .badRequest)
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }

        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }

    func testHandles401StatusCode() {
        let (sut, mock) = generateExampleWebServiceConfiguration()

        let response = HTTPURLResponse(url: sut.baseUrl, statusCode: 401, httpVersion: nil, headerFields: nil)
        mock.response = response

        sut.start { response in
            switch response {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .unauthorisedError)
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }

        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }

    func testHandles403StatusCode() {
        let (sut, mock) = generateExampleWebServiceConfiguration()

        let response = HTTPURLResponse(url: sut.baseUrl, statusCode: 403, httpVersion: nil, headerFields: nil)
        mock.response = response

        sut.start { response in
            switch response {
            case .success:
                XCTFail(self.failureExpectation)
            case .failure(let error as WebServiceError):
                XCTAssertEqual(error, .forbidden)
                self.testExpectation.fulfill()
            case .failure:
                XCTFail(self.expectedFailureForOtherReason)
            }
        }

        wait(for: [self.testExpectation], timeout: self.testTimeout)
    }
}
