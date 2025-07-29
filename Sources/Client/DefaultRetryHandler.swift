//
//  BasicRetryHandler.swift
//  SRGenericNetworkLayer
//
//  Created by Siamak on 12/16/24.
//

// MARK: - BasicRetryHandler.swift

import Foundation

/// A basic implementation of RetryHandler that uses all default behaviors
public struct DefaultRetryHandler: RetryHandler {
    
    public func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
        return numberOfRetries > 0
    }
    
    public func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
        return (request, nil)
    }
    
    public func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool {
        return numberOfRetries > 0
    }
    
    public func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest {
        return request
    }
    
    
    // MARK: Lifecycle

    public init(numberOfRetries: Int) {
        self.numberOfRetries = numberOfRetries
    }

    // MARK: Public

    public let numberOfRetries: Int
}
