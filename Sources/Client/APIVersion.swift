//
//  APIVersion.swift
//  SRGenericNetworkLayer
//
//  Created by Siamak on 11/30/24.
//

// MARK: - APIVersion

public enum APIVersion: Sendable {
    case v1
    case v2
    case custom(version: String)

    // MARK: Public

    public var path: String {
        "api/\(rawValue)/"
    }

    // MARK: Internal

    var rawValue: String {
        switch self {
        case .v1:
            return "v1"
        case .v2:
            return "v2"
        case .custom(let version):
            return version
        }
    }
}
