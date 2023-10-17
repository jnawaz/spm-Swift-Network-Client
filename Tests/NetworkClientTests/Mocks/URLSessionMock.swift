//
//  URLSessionMock.swift
//
//
//  Created by Jamil Nawaz on 17/10/2023.
//

import Foundation
@testable import NetworkClient

class URLSessionMock: NetworkSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?

    var willRequest: ((URLRequest) -> Void)?

    func loadData(from request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        willRequest?(request)
        DispatchQueue.global().async { [weak self] in
            completionHandler(self?.data, self?.response, self?.error)
        }
    }
}
