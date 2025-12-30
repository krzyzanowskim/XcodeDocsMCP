import XCTest
@testable import XcodeDocsMCPCore
import Foundation

// MARK: - RequestID Tests

final class RequestIDTests: XCTestCase {

    func testDecodeIntID() throws {
        let json = "42"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(RequestID.self, from: data)
        XCTAssertEqual(decoded, .int(42))
    }

    func testDecodeStringID() throws {
        let json = "\"request-123\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(RequestID.self, from: data)
        XCTAssertEqual(decoded, .string("request-123"))
    }

    func testDecodeNullID() throws {
        let json = "null"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(RequestID.self, from: data)
        XCTAssertEqual(decoded, .null)
    }

    func testEncodeIntID() throws {
        let id = RequestID.int(42)
        let data = try JSONEncoder().encode(id)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "42")
    }

    func testEncodeStringID() throws {
        let id = RequestID.string("request-123")
        let data = try JSONEncoder().encode(id)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "\"request-123\"")
    }

    func testEncodeNullID() throws {
        let id = RequestID.null
        let data = try JSONEncoder().encode(id)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "null")
    }

    func testDecodeInvalidID() {
        let json = "[1, 2, 3]"
        let data = Data(json.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(RequestID.self, from: data))
    }
}

// MARK: - AnyCodable Tests

final class AnyCodableTests: XCTestCase {

    func testDecodeString() throws {
        let json = "\"hello\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? String, "hello")
    }

    func testDecodeInt() throws {
        let json = "42"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testDecodeBool() throws {
        let json = "true"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testDecodeDouble() throws {
        let json = "3.14"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        if let value = decoded.value as? Double {
            XCTAssertEqual(value, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected Double value")
        }
    }

    func testDecodeNull() throws {
        let json = "null"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertTrue(decoded.value is NSNull)
    }

    func testDecodeArray() throws {
        let json = "[1, 2, 3]"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let array = decoded.value as? [Any]
        XCTAssertNotNil(array)
        XCTAssertEqual(array?.count, 3)
    }

    func testDecodeDictionary() throws {
        let json = "{\"key\": \"value\"}"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let dict = decoded.value as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["key"] as? String, "value")
    }

    func testDecodeNestedStructure() throws {
        let json = "{\"array\": [1, 2], \"nested\": {\"foo\": \"bar\"}}"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let dict = decoded.value as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertNotNil(dict?["array"] as? [Any])
        XCTAssertNotNil(dict?["nested"] as? [String: Any])
    }

    func testEncodeString() throws {
        let value = AnyCodable("hello")
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "\"hello\"")
    }

    func testEncodeInt() throws {
        let value = AnyCodable(42)
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "42")
    }

    func testEncodeBool() throws {
        let value = AnyCodable(true)
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "true")
    }

    func testEncodeNull() throws {
        let value = AnyCodable(NSNull())
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "null")
    }
}

// MARK: - JSONRPCRequest Tests

final class JSONRPCRequestTests: XCTestCase {

    func testDecodeBasicRequest() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 1, "method": "test"}
        """
        let data = Data(json.utf8)
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.id, .int(1))
        XCTAssertEqual(request.method, "test")
        XCTAssertNil(request.params)
    }

    func testDecodeRequestWithParams() throws {
        let json = """
        {"jsonrpc": "2.0", "id": "abc", "method": "tools/call", "params": {"name": "test", "arguments": {}}}
        """
        let data = Data(json.utf8)
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.id, .string("abc"))
        XCTAssertEqual(request.method, "tools/call")
        XCTAssertNotNil(request.params)

        let params = request.params?.value as? [String: Any]
        XCTAssertEqual(params?["name"] as? String, "test")
    }

    func testDecodeNotification() throws {
        let json = """
        {"jsonrpc": "2.0", "method": "notifications/initialized"}
        """
        let data = Data(json.utf8)
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertNil(request.id)
        XCTAssertEqual(request.method, "notifications/initialized")
    }

    func testEncodeRequest() throws {
        let request = JSONRPCRequest(
            jsonrpc: "2.0",
            id: .int(1),
            method: "test",
            params: nil
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, .int(1))
        XCTAssertEqual(decoded.method, "test")
    }
}

// MARK: - JSONRPCResponse Tests

final class JSONRPCResponseTests: XCTestCase {

    func testResponseWithResult() throws {
        let response = JSONRPCResponse(
            id: .int(1),
            result: AnyCodable(["foo": "bar"] as [String: String]),
            error: nil
        )

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, .int(1))
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)

        let result = response.result?.value as? [String: Any]
        XCTAssertEqual(result?["foo"] as? String, "bar")
    }

    func testResponseWithError() throws {
        let response = JSONRPCResponse(
            id: .int(1),
            result: nil,
            error: JSONRPCError(code: -32601, message: "Method not found")
        )

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, .int(1))
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32601)
        XCTAssertEqual(response.error?.message, "Method not found")
    }

    func testEncodeDecodeResponse() throws {
        let original = JSONRPCResponse(
            id: .string("test-id"),
            result: AnyCodable(42),
            error: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, .string("test-id"))
        XCTAssertEqual(decoded.result?.value as? Int, 42)
    }
}

// MARK: - MCPServer Request Handling Tests

final class MCPServerRequestHandlingTests: XCTestCase {

    @MainActor
    func testInitializeRequest() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "initialize",
            params: nil
        )

        let response = await server.handleRequest(request)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.id, .int(1))
        XCTAssertNil(response?.error)
        XCTAssertNotNil(response?.result)

        let result = response?.result?.value as? [String: Any]
        XCTAssertEqual(result?["protocolVersion"] as? String, "2025-06-18")
        XCTAssertNotNil(result?["serverInfo"])
        let capabilities = result?["capabilities"] as? [String: Any]
        XCTAssertNotNil(capabilities)
        let toolsCaps = capabilities?["tools"] as? [String: Any]
        XCTAssertEqual(toolsCaps?["listChanged"] as? Bool, false)
    }

    @MainActor
    func testInitializeRequestWithOlderVersion() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "initialize",
            params: AnyCodable([
                "protocolVersion": "2024-11-05",
                "capabilities": [String: String](),
                "clientInfo": ["name": "test", "version": "1.0"] as [String: String]
            ] as [String: any Sendable])
        )

        let response = await server.handleRequest(request)

        let result = response?.result?.value as? [String: Any]
        XCTAssertEqual(result?["protocolVersion"] as? String, "2024-11-05")
    }

    @MainActor
    func testInitializedNotification() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: nil,
            method: "notifications/initialized",
            params: nil
        )

        let response = await server.handleRequest(request)

        // Notifications don't get responses
        XCTAssertNil(response)
    }

    @MainActor
    func testUnknownNotificationDoesNotRespond() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: nil,
            method: "notifications/unknown",
            params: nil
        )

        let response = await server.handleRequest(request)

        XCTAssertNil(response)
    }

    @MainActor
    func testToolsListRequest() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(2),
            method: "tools/list",
            params: nil
        )

        let response = await server.handleRequest(request)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.id, .int(2))
        XCTAssertNil(response?.error)

        let result = response?.result?.value as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]]
        XCTAssertNotNil(tools)
        XCTAssertGreaterThan(tools?.count ?? 0, 0)

        // Verify expected tools are present
        let toolNames = tools?.compactMap { $0["name"] as? String }
        XCTAssertTrue(toolNames?.contains("search_documentation") ?? false)
        XCTAssertTrue(toolNames?.contains("get_symbol_info") ?? false)
        XCTAssertTrue(toolNames?.contains("list_frameworks") ?? false)
        XCTAssertTrue(toolNames?.contains("extract_module_symbols") ?? false)
    }

    @MainActor
    func testPingRequest() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .string("ping-test"),
            method: "ping",
            params: nil
        )

        let response = await server.handleRequest(request)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.id, .string("ping-test"))
        XCTAssertNil(response?.error)
        XCTAssertNotNil(response?.result)
    }

    @MainActor
    func testUnknownMethod() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(99),
            method: "unknown/method",
            params: nil
        )

        let response = await server.handleRequest(request)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.id, .int(99))
        XCTAssertNil(response?.result)
        XCTAssertNotNil(response?.error)
        XCTAssertEqual(response?.error?.code, -32601)
        XCTAssertTrue(response?.error?.message.contains("Method not found") ?? false)
    }
}

// MARK: - MCPServer Tool Call Tests

final class MCPServerToolCallTests: XCTestCase {

    @MainActor
    func testToolCallInvalidParams() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable("not a dictionary")
        )

        let response = await server.handleToolCall(request)

        XCTAssertEqual(response.id, .int(1))
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertEqual(response.error?.message, "Invalid params")
    }

    @MainActor
    func testToolCallMissingToolName() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable(["arguments": [String: String]()] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
    }

    @MainActor
    func testToolCallUnknownTool() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable([
                "name": "unknown_tool",
                "arguments": [String: String]()
            ] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertTrue(response.error?.message.contains("Unknown tool") ?? false)
    }

    @MainActor
    func testSearchDocumentationMissingQuery() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable([
                "name": "search_documentation",
                "arguments": [String: String]()
            ] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertTrue(response.error?.message.contains("query") ?? false)
    }

    @MainActor
    func testSearchDocumentationEmptyQuery() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable([
                "name": "search_documentation",
                "arguments": ["query": ""] as [String: String]
            ] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertTrue(response.error?.message.contains("query") ?? false)
    }

    @MainActor
    func testGetSymbolInfoMissingModule() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable([
                "name": "get_symbol_info",
                "arguments": ["symbol": "URL"] as [String: String]
            ] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertTrue(response.error?.message.contains("module") ?? false)
    }

    @MainActor
    func testGetSymbolInfoMissingSymbol() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable([
                "name": "get_symbol_info",
                "arguments": ["module": "Foundation"] as [String: String]
            ] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertTrue(response.error?.message.contains("symbol") ?? false)
    }

    @MainActor
    func testExtractModuleSymbolsMissingModule() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable([
                "name": "extract_module_symbols",
                "arguments": [String: String]()
            ] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertTrue(response.error?.message.contains("module") ?? false)
    }
}

// MARK: - Relevance Score Tests

final class RelevanceScoreTests: XCTestCase {

    @MainActor
    func testExactFilenameMatch() {
        let server = MCPServer()
        let score = server.calculateRelevanceScore(
            path: "/Frameworks/Foundation.framework/Headers/NSWindow.h",
            query: "NSWindow"
        )

        // Should get points for exact match, header file, and framework headers
        XCTAssertGreaterThan(score, 100)
    }

    @MainActor
    func testHeaderFileBonus() {
        let server = MCPServer()
        let headerScore = server.calculateRelevanceScore(
            path: "/path/to/file.h",
            query: "test"
        )
        let otherScore = server.calculateRelevanceScore(
            path: "/path/to/file.txt",
            query: "test"
        )

        XCTAssertGreaterThan(headerScore, otherScore)
    }

    @MainActor
    func testSwiftInterfaceBonus() {
        let server = MCPServer()
        let swiftScore = server.calculateRelevanceScore(
            path: "/path/to/module.swiftinterface",
            query: "test"
        )
        let otherScore = server.calculateRelevanceScore(
            path: "/path/to/module.txt",
            query: "test"
        )

        XCTAssertGreaterThan(swiftScore, otherScore)
    }

    @MainActor
    func testFrameworkHeadersBonus() {
        let server = MCPServer()
        let frameworkScore = server.calculateRelevanceScore(
            path: "/System/Library/Frameworks/Foundation.framework/Headers/NSObject.h",
            query: "NSObject"
        )
        let regularScore = server.calculateRelevanceScore(
            path: "/usr/include/NSObject.h",
            query: "NSObject"
        )

        XCTAssertGreaterThan(frameworkScore, regularScore)
    }

    @MainActor
    func testPrefixMatch() {
        let server = MCPServer()
        let prefixScore = server.calculateRelevanceScore(
            path: "/path/to/NSWindowController.h",
            query: "NSWindow"
        )
        let noMatchScore = server.calculateRelevanceScore(
            path: "/path/to/Something.h",
            query: "NSWindow"
        )

        XCTAssertGreaterThan(prefixScore, noMatchScore)
    }

    @MainActor
    func testDocumentationPathBonus() {
        let server = MCPServer()
        let docScore = server.calculateRelevanceScore(
            path: "/Developer/Documentation/something.docarchive",
            query: "test"
        )
        let regularScore = server.calculateRelevanceScore(
            path: "/Developer/something.txt",
            query: "test"
        )

        XCTAssertGreaterThan(docScore, regularScore)
    }

    @MainActor
    func testCaseInsensitiveMatch() {
        let server = MCPServer()
        let lowerScore = server.calculateRelevanceScore(
            path: "/path/to/nswindow.h",
            query: "NSWindow"
        )

        // Should still get points for case-insensitive match
        XCTAssertGreaterThan(lowerScore, 0)
    }
}

// MARK: - Tools List Tests

final class ToolsListTests: XCTestCase {

    @MainActor
    func testToolsListStructure() {
        let server = MCPServer()
        let tools = server.getToolsList()

        XCTAssertEqual(tools.count, 4)

        for tool in tools {
            XCTAssertNotNil(tool["name"] as? String)
            XCTAssertNotNil(tool["description"] as? String)
            XCTAssertNotNil(tool["inputSchema"] as? [String: Any])
        }
    }

    @MainActor
    func testSearchDocumentationSchema() {
        let server = MCPServer()
        let tools = server.getToolsList()
        let searchTool = tools.first { ($0["name"] as? String) == "search_documentation" }

        XCTAssertNotNil(searchTool)

        let schema = searchTool?["inputSchema"] as? [String: Any]
        XCTAssertEqual(schema?["type"] as? String, "object")

        let properties = schema?["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["query"])
        XCTAssertNotNil(properties?["limit"])

        let required = schema?["required"] as? [String]
        XCTAssertTrue(required?.contains("query") ?? false)
    }

    @MainActor
    func testGetSymbolInfoSchema() {
        let server = MCPServer()
        let tools = server.getToolsList()
        let symbolTool = tools.first { ($0["name"] as? String) == "get_symbol_info" }

        XCTAssertNotNil(symbolTool)

        let schema = symbolTool?["inputSchema"] as? [String: Any]
        let required = schema?["required"] as? [String]

        XCTAssertTrue(required?.contains("module") ?? false)
        XCTAssertTrue(required?.contains("symbol") ?? false)
    }

    @MainActor
    func testListFrameworksSchema() {
        let server = MCPServer()
        let tools = server.getToolsList()
        let frameworksTool = tools.first { ($0["name"] as? String) == "list_frameworks" }

        XCTAssertNotNil(frameworksTool)

        let schema = frameworksTool?["inputSchema"] as? [String: Any]
        let properties = schema?["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["filter"])

        // filter is optional, so no required array or empty
        let required = schema?["required"] as? [String]
        XCTAssertTrue(required == nil || required?.isEmpty == true || !(required?.contains("filter") ?? false))
    }

    @MainActor
    func testExtractModuleSymbolsSchema() {
        let server = MCPServer()
        let tools = server.getToolsList()
        let extractTool = tools.first { ($0["name"] as? String) == "extract_module_symbols" }

        XCTAssertNotNil(extractTool)

        let schema = extractTool?["inputSchema"] as? [String: Any]
        let properties = schema?["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["module"])
        XCTAssertNotNil(properties?["kind"])

        let required = schema?["required"] as? [String]
        XCTAssertTrue(required?.contains("module") ?? false)
    }
}

// MARK: - Integration Tests (require Xcode)

final class IntegrationTests: XCTestCase {

    @MainActor
    func testListFrameworks() async throws {
        let server = MCPServer()
        let result = await server.listFrameworks(filter: nil)

        // Should return a list of frameworks
        XCTAssertTrue(result.contains("Available frameworks"))
        XCTAssertTrue(result.contains("Foundation"))
    }

    @MainActor
    func testListFrameworksWithFilter() async throws {
        let server = MCPServer()
        let result = await server.listFrameworks(filter: "Swift")

        // Should filter to Swift-related frameworks
        XCTAssertTrue(result.contains("Swift") || result.contains("No frameworks found"))
    }

    @MainActor
    func testGetSDKPath() {
        let server = MCPServer()
        let sdkPath = server.getSDKPath()

        // Should return a valid SDK path
        XCTAssertTrue(sdkPath.contains("SDK") || sdkPath.contains("sdk"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sdkPath))
    }

    @MainActor
    func testSearchDocumentationValidQuery() async throws {
        let server = MCPServer()
        let result = await server.searchDocumentation(query: "NSObject", limit: 5)

        // Should return some results or a helpful message
        XCTAssertFalse(result.isEmpty)
        // Either found results or gave suggestions
        XCTAssertTrue(result.contains("NSObject") || result.contains("documentation") || result.contains("Suggestions"))
    }

    @MainActor
    func testGetSymbolInfoFoundation() async throws {
        let server = MCPServer()
        let result = await server.getSymbolInfo(module: "Foundation", symbol: "URL")

        // Should find URL in Foundation
        XCTAssertTrue(result.contains("URL") || result.contains("not found"))
    }

    @MainActor
    func testGetSymbolInfoNonexistentModule() async throws {
        let server = MCPServer()
        let result = await server.getSymbolInfo(module: "NonexistentModule123", symbol: "Test")

        // Should return appropriate error
        XCTAssertTrue(result.contains("not found") || result.contains("Module"))
    }

    @MainActor
    func testExtractModuleSymbols() async throws {
        let server = MCPServer()
        let result = await server.extractModuleSymbols(module: "Foundation", kind: "all")

        // Should return symbols or an appropriate message
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Foundation") || result.contains("Objective-C") || result.contains("symbols") || result.contains("Could not"))
    }

    @MainActor
    func testExtractModuleSymbolsFilteredByKind() async throws {
        let server = MCPServer()
        let result = await server.extractModuleSymbols(module: "SwiftUI", kind: "struct")

        // Should return filtered results
        XCTAssertFalse(result.isEmpty)
    }
}

// MARK: - MCPServer Message Processing Tests

final class MCPServerMessageProcessingTests: XCTestCase {

    @MainActor
    func testProcessMessageEmptyBatchReturnsInvalidRequest() async {
        let server = MCPServer()
        let output = await server.processMessageData(Data("[]".utf8))

        switch output {
        case .single(let response):
            XCTAssertEqual(response.id, .null)
            XCTAssertEqual(response.error?.code, -32600)
        default:
            XCTFail("Expected single invalid request response for empty batch")
        }
    }

    @MainActor
    func testProcessMessageBatchWithInvalidElement() async {
        let server = MCPServer()
        let json = "[{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"ping\"}, 1]"
        let output = await server.processMessageData(Data(json.utf8))

        switch output {
        case .batch(let responses):
            XCTAssertEqual(responses.count, 2)
            XCTAssertEqual(responses[0].id, .int(1))
            XCTAssertNil(responses[0].error)
            XCTAssertEqual(responses[1].id, .null)
            XCTAssertEqual(responses[1].error?.code, -32600)
        default:
            XCTFail("Expected batch responses for mixed valid and invalid requests")
        }
    }

    @MainActor
    func testProcessMessageInvalidSingleReturnsInvalidRequest() async {
        let server = MCPServer()
        let output = await server.processMessageData(Data("1".utf8))

        switch output {
        case .single(let response):
            XCTAssertEqual(response.id, .null)
            XCTAssertEqual(response.error?.code, -32600)
        default:
            XCTFail("Expected invalid request response for non-object payload")
        }
    }
}

// MARK: - End-to-End Protocol Tests

final class EndToEndProtocolTests: XCTestCase {

    @MainActor
    func testFullInitializationSequence() async {
        let server = MCPServer()

        // 1. Send initialize
        let initRequest = JSONRPCRequest(
            id: .int(1),
            method: "initialize",
            params: AnyCodable([
                "protocolVersion": "2025-06-18",
                "capabilities": [String: String](),
                "clientInfo": ["name": "test", "version": "1.0"] as [String: String]
            ] as [String: any Sendable])
        )

        let initResponse = await server.handleRequest(initRequest)
        XCTAssertNotNil(initResponse)
        XCTAssertNil(initResponse?.error)

        // 2. Send initialized notification
        let initializedNotification = JSONRPCRequest(
            id: nil,
            method: "notifications/initialized",
            params: nil
        )

        let initdResponse = await server.handleRequest(initializedNotification)
        XCTAssertNil(initdResponse) // Notifications don't get responses

        // 3. Get tools list
        let toolsRequest = JSONRPCRequest(
            id: .int(2),
            method: "tools/list",
            params: nil
        )

        let toolsResponse = await server.handleRequest(toolsRequest)
        XCTAssertNotNil(toolsResponse)
        XCTAssertNil(toolsResponse?.error)

        let result = toolsResponse?.result?.value as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 4)
    }

    @MainActor
    func testToolCallWithValidResponse() async {
        let server = MCPServer()
        let request = JSONRPCRequest(
            id: .int(1),
            method: "tools/call",
            params: AnyCodable([
                "name": "list_frameworks",
                "arguments": ["filter": "Foundation"] as [String: String]
            ] as [String: any Sendable])
        )

        let response = await server.handleToolCall(request)

        XCTAssertEqual(response.id, .int(1))
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)

        // Verify response structure matches MCP spec
        let result = response.result?.value as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        XCTAssertNotNil(content)
        XCTAssertGreaterThan(content?.count ?? 0, 0)

        XCTAssertEqual(result?["isError"] as? Bool, false)

        let firstContent = content?.first
        XCTAssertEqual(firstContent?["type"] as? String, "text")
        XCTAssertNotNil(firstContent?["text"])
    }
}
