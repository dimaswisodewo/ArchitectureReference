import XCTest
@testable import ArchitectureReference

final class ViewStateTests: XCTestCase {
    func testDataIsAvailableWhileLoadingOrShowingFailure() {
        // Arrange
        let profile = ProfileEntity.fixture()
        let loadingState: ViewState<ProfileEntity> = .loading(previousData: profile)
        let failureState: ViewState<ProfileEntity> = .failure(TestError.expected, previousData: profile)

        // Act
        let loadingData = loadingState.data
        let failureData = failureState.data

        // Assert
        XCTAssertEqual(loadingData, profile)
        XCTAssertTrue(loadingState.isLoading)
        XCTAssertEqual(failureData, profile)
        XCTAssertEqual(failureState.errorMessage, TestError.expected.localizedDescription)
    }
}

final class DependencyContainerTests: XCTestCase {
    func testRegisterInstanceReturnsTheSameObject() throws {
        // Arrange
        let container = DependencyContainer()
        let networkClient = URLSessionNetworkClient()
        container.registerInstance(NetworkClient.self, instance: networkClient)

        // Act
        let first: NetworkClient = try container.resolve()
        let second: NetworkClient = try container.resolve()

        // Assert
        XCTAssertTrue((first as AnyObject) === (second as AnyObject))
    }

    func testResolveThrowsWhenDependencyIsMissing() {
        // Arrange
        let container = DependencyContainer()

        // Act
        XCTAssertThrowsError(try container.resolve() as NetworkClient) { error in
            // Assert
            guard case DIError.missingDependency = error else {
                return XCTFail("Expected missingDependency, received \(error)")
            }
        }
    }

    @MainActor
    func testProfileAssemblyRegistersProfileViewModel() throws {
        // Arrange
        let container = DependencyContainer()
        ArchitectureReferenceApp.setupDependencies(in: container)
        let navigator = ProfileNavigatorSpy()
        ProfileAssembly(navigator: navigator).assemble(container: container)

        // Act
        let viewModel: ProfileViewModel = try container.resolve()

        // Assert
        XCTAssertEqual(viewModel.state, .idle)
    }
}

final class EndpointTests: XCTestCase {
    func testPokemonListEndpointBuildsQueryAndHeaders() throws {
        // Arrange
        let endpoint = PokemonEndpoint.list(limit: 20, offset: 40)

        // Act
        guard case .requestParameters(let parameters, let encoding) = endpoint.task else {
            return XCTFail("Expected URL request parameters")
        }

        // Assert
        XCTAssertEqual(endpoint.path, "api/v2/pokemon")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.headers?["Accept"], "application/json")
        XCTAssertEqual(parameters["limit"] as? Int, 20)
        XCTAssertEqual(parameters["offset"] as? Int, 40)
        XCTAssertEqual(encoding, .url)
    }

    func testPokemonDetailEndpointBuildsIdentifierPath() {
        // Arrange
        let endpoint = PokemonEndpoint.detail(identifier: 25)

        // Act
        let path = endpoint.path

        // Assert
        XCTAssertEqual(path, "api/v2/pokemon/25")
        guard case .requestPlain = endpoint.task else {
            return XCTFail("Expected a plain request")
        }
    }
}

final class URLSessionNetworkClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testRequestBuildsURLHeadersAndDecodesResponse() async throws {
        // Arrange
        URLProtocolStub.requestHandler = { request in
            let queryItems = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
            let query = Set(queryItems.map { "\($0.name)=\($0.value ?? "")" })
            XCTAssertEqual(query, ["limit=20", "offset=40"])
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return Self.httpResponse(statusCode: 200, url: request.url!, data: Data(#"{"value":"ok"}"#.utf8))
        }
        let client = URLSessionNetworkClient(session: makeURLSession())

        // Act
        let response: TestResponse = try await client.request(TestEndpoint.list)

        // Assert
        XCTAssertEqual(response.value, "ok")
    }

    func testRequestThrowsForNonSuccessStatusCode() async {
        // Arrange
        URLProtocolStub.requestHandler = { request in
            Self.httpResponse(statusCode: 503, url: request.url!, data: Data())
        }
        let client = URLSessionNetworkClient(session: makeURLSession())

        // Act
        do {
            let _: TestResponse = try await client.request(TestEndpoint.list)
            XCTFail("Expected a server error")
            // Assert
        } catch let error as NSError {
            // Assert
            XCTAssertEqual(error.code, 503)
            XCTAssertEqual(error.localizedDescription, "Server returned status code 503")
        } catch {
            // Assert
            XCTFail("Expected NSError, received \(error)")
        }
    }

    func testRequestEncodesJSONBody() async throws {
        // Arrange
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try XCTUnwrap(request.httpBody ?? request.httpBodyStream.flatMap(Self.readBody))
            XCTAssertEqual(String(decoding: body, as: UTF8.self), #"{"name":"Dimas"}"#)
            return Self.httpResponse(statusCode: 200, url: request.url!, data: Data(#"{"value":"saved"}"#.utf8))
        }
        let client = URLSessionNetworkClient(session: makeURLSession())

        // Act
        let response: TestResponse = try await client.request(
            TestEndpoint.save(payload: TestPayload(name: "Dimas"))
        )

        // Assert
        XCTAssertEqual(response.value, "saved")
    }

    private func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func httpResponse(statusCode: Int, url: URL, data: Data) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, data)
    }

    private static func readBody(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private struct TestResponse: Decodable { let value: String }
private struct TestPayload: Encodable { let name: String }

private enum TestEndpoint: APIEndpoint {
    case list
    case save(payload: TestPayload)

    var baseURL: URL { URL(string: "https://example.com")! }
    var path: String {
        switch self {
        case .list: return "items"
        case .save: return "items/1"
        }
    }
    var method: HTTPMethod {
        switch self {
        case .list: return .get
        case .save: return .post
        }
    }
    var headers: [String: String]? { ["Accept": "application/json"] }
    var task: HTTPTask {
        switch self {
        case .list:
            return .requestParameters(parameters: ["limit": 20, "offset": 40], encoding: .url)
        case .save(let payload):
            return .requestJSONEncodable(encodable: payload)
        }
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.requestHandler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class ProfileNavigatorSpy: ProfileNavigator {
    func navigateToSettings() {}
    func dismiss(animated: Bool) {}
    func pop(animated: Bool) {}
}
