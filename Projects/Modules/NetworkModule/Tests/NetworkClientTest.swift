import XCTest

@testable import NetworkModule
@testable import NetworkModuleInterface
@testable import NetworkModuleTesting

final class NetworkClientTest: XCTestCase {
    var session: URLSessionProtocol!
    var client: NetworkClient<MockEndpoint>!

    func test_success_response() async throws {
        session = MockURLSession(data: mockData, response: mockSuccessResponse)
        client = NetworkClient(session: session)
        let mockEndpoint = MockEndpoint.fetch
        
        let response = try await client.request(mockEndpoint)
        guard let httpResponse = response.response as? HTTPURLResponse else { return XCTFail("HTTP 응답이 아닙니다.") }
        
        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertEqual(response.data, mockData)
    }
    
    func test_bad_gateway_response() async throws {
        session = MockURLSession(data: mockData, response: mockBadGatewayResponse)
        client = NetworkClient(session: session)
        let mockEndpoint = MockEndpoint.fetch
        
        var result: HTTPError?
        do {
            _ = try await client.request(mockEndpoint)
        } catch let error as HTTPError {
            result = error
        }
        
        let expectation = HTTPError.badGateway
        XCTAssertEqual(result, expectation)
    }
    
    func test_bad_request_response() async throws {
        session = MockURLSession(data: mockData, response: mockBadRequestResponse)
        client = NetworkClient(session: session)
        let mockEndpoint = MockEndpoint.fetch
        
        var result: HTTPError?
        do {
            _ = try await client.request(mockEndpoint)
        } catch let error as HTTPError {
            result = error
        }
        
        let expectation = HTTPError.badRequest
        XCTAssertEqual(result, expectation)
    }
}
