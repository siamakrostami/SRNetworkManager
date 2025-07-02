import XCTest
@testable import SRNetworkManager // Replace with your actual module name

final class NetworkRouterTests: XCTestCase {
        // MARK: - Mock Router
    
    enum MockRouter: NetworkRouter {
        case testEndpoint(queryParams: MockQueryParams?, bodyParams: MockBodyParams?)
        
        var baseURLString: String {
            return "https://api.example.com"
        }
        
        var method: RequestMethod? {
            return .post
        }
        
        var path: String {
            return "/test"
        }
        
        var headers: [String: String]? {
            return ["Content-Type": "application/json"]
        }
        
        var params: MockBodyParams? {
            switch self {
                case .testEndpoint(_, let bodyParams):
                    return bodyParams
            }
        }
        
        var queryParams: MockQueryParams? {
            switch self {
                case .testEndpoint(let queryParams, _):
                    return queryParams
            }
        }
    }
    
        // MARK: - Mock Models
    
    struct MockQueryParams: Codable, Equatable {
        let id: String
        let filter: String?
    }
    
    struct MockBodyParams: Codable, Equatable {
        let name: String
        let age: Int
    }
    
        // MARK: - Tests
    
    func testRouterWithBothQueryAndBodyParams() throws {
            // Given
        let queryParams = MockQueryParams(id: "123", filter: "active")
        let bodyParams = MockBodyParams(name: "John", age: 30)
        let router = MockRouter.testEndpoint(queryParams: queryParams, bodyParams: bodyParams)
        
            // When
        let request = try router.asURLRequest()
        
            // Then
        XCTAssertNotNil(request.url)
        XCTAssertNotNil(request.httpBody)
        
            // Verify URL and query parameters
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("id=123"))
        XCTAssertTrue(urlString.contains("filter=active"))
        XCTAssertTrue(urlString.hasPrefix("https://api.example.com/test"))
        
            // Verify body parameters
        let bodyData = request.httpBody!
        let decodedBody = try JSONDecoder().decode(MockBodyParams.self, from: bodyData)
        XCTAssertEqual(decodedBody, bodyParams)
        
            // Verify headers
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testRouterWithOnlyQueryParams() throws {
            // Given
        let queryParams = MockQueryParams(id: "456", filter: nil)
        let router = MockRouter.testEndpoint(queryParams: queryParams, bodyParams: nil)
        
            // When
        let request = try router.asURLRequest()
        
            // Then
        XCTAssertNotNil(request.url)
        XCTAssertTrue(request.httpBody == nil || request.httpBody?.isEmpty == true)
        
            // Verify URL and query parameters
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("id=456"))
        XCTAssertFalse(urlString.contains("filter="))
    }
    
    func testRouterWithOnlyBodyParams() throws {
            // Given
        let bodyParams = MockBodyParams(name: "Jane", age: 25)
        let router = MockRouter.testEndpoint(queryParams: nil, bodyParams: bodyParams)
        
            // When
        let request = try router.asURLRequest()
        
            // Then
        XCTAssertNotNil(request.url)
        XCTAssertNotNil(request.httpBody)
        
            // Verify URL has no query parameters
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertFalse(urlString.contains("?"))
        
            // Verify body parameters
        let bodyData = request.httpBody!
        let decodedBody = try JSONDecoder().decode(MockBodyParams.self, from: bodyData)
        XCTAssertEqual(decodedBody, bodyParams)
    }
    
    func testRouterWithEmptyParams() throws {
            // Given
        let router = MockRouter.testEndpoint(queryParams: nil, bodyParams: nil)
        
            // When
        let request = try router.asURLRequest()
        
            // Then
        XCTAssertNotNil(request.url)
        XCTAssertTrue(request.httpBody == nil || request.httpBody?.isEmpty == true)
        XCTAssertFalse(request.url?.absoluteString.contains("?") ?? false)
    }
    
    func testURLEncodingWithSpecialCharacters() throws {
            // Given
        let queryParams = MockQueryParams(id: "test@example.com", filter: "special&chars")
        let router = MockRouter.testEndpoint(queryParams: queryParams, bodyParams: nil)
        
            // When
        let request = try router.asURLRequest()
        
            // Then
        XCTAssertNotNil(request.url)
        let urlString = request.url?.absoluteString ?? ""
        
            // Verify special characters are properly encoded
        XCTAssertTrue(urlString.contains("id=test@example.com"))
        XCTAssertTrue(urlString.contains("filter=special&chars"))
    }
    
}
