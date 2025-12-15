import Foundation

// MARK: - JSON-RPC Types

struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: RequestID?
    let method: String
    let params: AnyCodable?
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: RequestID?
    let result: AnyCodable?
    let error: JSONRPCError?

    init(id: RequestID?, result: AnyCodable?, error: JSONRPCError?) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

enum RequestID: Codable, Equatable {
    case string(String)
    case int(Int)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(RequestID.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int, String, or null"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - AnyCodable for dynamic JSON

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - MCP Server

@MainActor
final class MCPServer {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let serverInfo: [String: Any] = [
        "name": "xcode-docs-mcp",
        "version": "1.0.0"
    ]

    private let capabilities: [String: Any] = [
        "tools": [String: Any]()
    ]

    init() {
        encoder.outputFormatting = []
    }

    func run() async {
        // Read from stdin line by line
        while let line = readLine() {
            guard !line.isEmpty else { continue }

            do {
                let request = try decoder.decode(JSONRPCRequest.self, from: Data(line.utf8))
                let response = await handleRequest(request)
                if let response = response {
                    try sendResponse(response)
                }
            } catch {
                let errorResponse = JSONRPCResponse(
                    id: nil,
                    result: nil,
                    error: JSONRPCError(code: -32700, message: "Parse error: \(error.localizedDescription)", data: nil)
                )
                try? sendResponse(errorResponse)
            }
        }
    }

    private func sendResponse(_ response: JSONRPCResponse) throws {
        let data = try encoder.encode(response)
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
            fflush(stdout)
        }
    }

    private func handleRequest(_ request: JSONRPCRequest) async -> JSONRPCResponse? {
        switch request.method {
        case "initialize":
            return JSONRPCResponse(
                id: request.id,
                result: AnyCodable([
                    "protocolVersion": "2024-11-05",
                    "serverInfo": serverInfo,
                    "capabilities": capabilities
                ]),
                error: nil
            )

        case "initialized":
            // Notification, no response needed
            return nil

        case "tools/list":
            return JSONRPCResponse(
                id: request.id,
                result: AnyCodable([
                    "tools": getToolsList()
                ]),
                error: nil
            )

        case "tools/call":
            return await handleToolCall(request)

        case "ping":
            return JSONRPCResponse(
                id: request.id,
                result: AnyCodable([String: Any]()),
                error: nil
            )

        default:
            return JSONRPCResponse(
                id: request.id,
                result: nil,
                error: JSONRPCError(code: -32601, message: "Method not found: \(request.method)", data: nil)
            )
        }
    }

    private func getToolsList() -> [[String: Any]] {
        return [
            [
                "name": "search_documentation",
                "description": "Search Apple's developer documentation using Spotlight. Returns matching documentation entries for frameworks, classes, methods, and other symbols.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Search query (e.g., 'NSWindow', 'SwiftUI View', 'URLSession')"
                        ],
                        "limit": [
                            "type": "integer",
                            "description": "Maximum number of results to return (default: 20)",
                            "default": 20
                        ]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "get_symbol_info",
                "description": "Get detailed information about a specific symbol from the SDK using swift-symbolgraph-extract. Returns the symbol's declaration, documentation, and relationships.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "module": [
                            "type": "string",
                            "description": "The module/framework name (e.g., 'Foundation', 'SwiftUI', 'AppKit')"
                        ],
                        "symbol": [
                            "type": "string",
                            "description": "The symbol name to look up (e.g., 'URL', 'View', 'NSWindow')"
                        ]
                    ],
                    "required": ["module", "symbol"]
                ]
            ],
            [
                "name": "list_frameworks",
                "description": "List available Apple frameworks/modules in the macOS SDK.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "filter": [
                            "type": "string",
                            "description": "Optional filter to match framework names (case-insensitive)"
                        ]
                    ]
                ]
            ],
            [
                "name": "extract_module_symbols",
                "description": "Extract all public symbols from a module/framework. Useful for discovering available types, functions, and properties.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "module": [
                            "type": "string",
                            "description": "The module/framework name (e.g., 'Foundation', 'SwiftUI')"
                        ],
                        "kind": [
                            "type": "string",
                            "description": "Filter by symbol kind: 'struct', 'class', 'enum', 'protocol', 'func', 'var', or 'all' (default: 'all')",
                            "default": "all"
                        ]
                    ],
                    "required": ["module"]
                ]
            ]
        ]
    }

    private func handleToolCall(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        guard let params = request.params?.value as? [String: Any],
              let toolName = params["name"] as? String,
              let arguments = params["arguments"] as? [String: Any] else {
            return JSONRPCResponse(
                id: request.id,
                result: nil,
                error: JSONRPCError(code: -32602, message: "Invalid params", data: nil)
            )
        }

        let result: String

        switch toolName {
        case "search_documentation":
            guard let query = arguments["query"] as? String, !query.isEmpty else {
                return JSONRPCResponse(
                    id: request.id,
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Missing required parameter: query", data: nil)
                )
            }
            let limit = arguments["limit"] as? Int ?? 20
            result = await searchDocumentation(query: query, limit: limit)

        case "get_symbol_info":
            guard let module = arguments["module"] as? String, !module.isEmpty else {
                return JSONRPCResponse(
                    id: request.id,
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Missing required parameter: module", data: nil)
                )
            }
            guard let symbol = arguments["symbol"] as? String, !symbol.isEmpty else {
                return JSONRPCResponse(
                    id: request.id,
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Missing required parameter: symbol", data: nil)
                )
            }
            result = await getSymbolInfo(module: module, symbol: symbol)

        case "list_frameworks":
            let filter = arguments["filter"] as? String
            result = await listFrameworks(filter: filter)

        case "extract_module_symbols":
            guard let module = arguments["module"] as? String, !module.isEmpty else {
                return JSONRPCResponse(
                    id: request.id,
                    result: nil,
                    error: JSONRPCError(code: -32602, message: "Missing required parameter: module", data: nil)
                )
            }
            let kind = arguments["kind"] as? String ?? "all"
            result = await extractModuleSymbols(module: module, kind: kind)

        default:
            return JSONRPCResponse(
                id: request.id,
                result: nil,
                error: JSONRPCError(code: -32602, message: "Unknown tool: \(toolName)", data: nil)
            )
        }

        return JSONRPCResponse(
            id: request.id,
            result: AnyCodable([
                "content": [
                    ["type": "text", "text": result]
                ]
            ]),
            error: nil
        )
    }

    // MARK: - Tool Implementations

    private func searchDocumentation(query: String, limit: Int) async -> String {
        var allResults: [(path: String, score: Int)] = []
        var headerResults: String? = nil
        var symbolResults: [(framework: String, symbol: String, kind: String)] = []

        // Strategy 1: Search documentation cache with better query
        let docResults = await searchSpotlightDocumentation(query: query)
        allResults.append(contentsOf: docResults)

        // Strategy 2: Search SDK headers if we don't have enough results
        if allResults.count < limit {
            let headers = await searchInSDKHeaders(query: query, limit: limit)
            if !headers.contains("No documentation found") && !headers.contains("Error") {
                headerResults = headers
            }
        }

        // Strategy 3: Try case-insensitive symbol name search in frameworks
        // Run this even if we have header results, when spotlight results are few
        if allResults.count < 5 {
            symbolResults = await searchSymbolAcrossFrameworks(query: query, limit: 10)
        }

        // Combine and format results based on what we found
        if allResults.isEmpty && headerResults == nil && symbolResults.isEmpty {
            return "No documentation found for '\(query)'.\n\nSuggestions:\n- Try searching for a more specific symbol name\n- Use get_symbol_info if you know the framework (e.g., Foundation, SwiftUI)\n- Use list_frameworks to see available frameworks"
        }

        // If we have symbol results and few other results, prefer symbol format
        if !symbolResults.isEmpty && allResults.count < 3 && headerResults == nil {
            return formatSymbolSearchResults(results: symbolResults, query: query)
        }

        // If we have header results, include them in combined output
        if let headers = headerResults {
            return formatCombinedResults(spotlightResults: allResults, headerResults: headers, query: query, limit: limit)
        }

        // Sort by relevance score and format results
        let sortedResults = allResults
            .sorted { $0.score > $1.score }
            .prefix(limit)

        return formatSpotlightResults(results: sortedResults.map { $0.path }, query: query)
    }

    private func searchSpotlightDocumentation(query: String) async -> [(path: String, score: Int)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")

        // Escape single quotes in query to prevent Spotlight query injection
        let escapedQuery = query.replacingOccurrences(of: "'", with: "\\'")

        // Build better search query focusing on documentation files
        // Look for exact matches first, then word-based matches
        let searchQuery = "(kMDItemDisplayName == '\(escapedQuery)'wc || kMDItemDisplayName == '*\(escapedQuery)*'wcd || kMDItemFSName == '*\(escapedQuery)*.h' || kMDItemFSName == '*\(escapedQuery)*.swift' || kMDItemTextContent == '*\(escapedQuery)*'wcd) && (kMDItemContentType == 'public.source-code' || kMDItemContentType == 'public.header' || kMDItemContentType == 'public.documentation')"

        let docPaths = [
            NSHomeDirectory() + "/Library/Developer/Xcode/DocumentationCache",
            "/Applications/Xcode.app/Contents/Developer/Documentation",
            "/Library/Developer/CommandLineTools/SDKs"
        ]

        var args = [String]()
        for path in docPaths {
            if FileManager.default.fileExists(atPath: path) {
                args.append(contentsOf: ["-onlyin", path])
            }
        }
        args.append(searchQuery)

        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        // Discard stderr to avoid potential deadlock (we don't need it)
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Read output before waitUntilExit to avoid pipe buffer deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: data, encoding: .utf8) ?? ""

            let lines = output.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }

            // Score each result based on relevance
            return lines.map { path in
                let score = calculateRelevanceScore(path: path, query: query)
                return (path: path, score: score)
            }
        } catch {
            return []
        }
    }

    private func calculateRelevanceScore(path: String, query: String) -> Int {
        var score = 0
        let lowercasePath = path.lowercased()
        let lowercaseQuery = query.lowercased()
        let fileName = (path as NSString).lastPathComponent.lowercased()

        // Exact filename match (highest priority)
        if fileName.contains(lowercaseQuery + ".") || fileName == lowercaseQuery {
            score += 100
        }

        // Header or Swift interface file
        if path.hasSuffix(".h") || path.hasSuffix(".swift") || path.hasSuffix(".swiftinterface") {
            score += 50
        }

        // In main framework headers directory
        if lowercasePath.contains("/frameworks/") && lowercasePath.contains("/headers/") {
            score += 30
        }

        // Symbol name is part of path
        if fileName.hasPrefix(lowercaseQuery) {
            score += 25
        }

        // Documentation files
        if lowercasePath.contains("/documentation/") || lowercasePath.contains(".docarchive") {
            score += 20
        }

        // Contains query as whole word
        if fileName.contains(lowercaseQuery) {
            score += 15
        }

        // Framework name matches
        if let frameworkRange = lowercasePath.range(of: "/frameworks/") {
            let afterFrameworks = String(lowercasePath[frameworkRange.upperBound...])
            if afterFrameworks.hasPrefix(lowercaseQuery) {
                score += 40
            }
        }

        return score
    }

    private func formatSpotlightResults(results: [String], query: String) -> String {
        var formatted = ["Documentation search results for '\(query)':", ""]

        for (index, path) in results.enumerated() {
            let fileName = (path as NSString).lastPathComponent
            var components: [String] = []

            // Extract framework name
            if let range = path.range(of: "/Frameworks/") {
                let afterFrameworks = String(path[range.upperBound...])
                if let frameworkEnd = afterFrameworks.firstIndex(of: "/") {
                    let framework = String(afterFrameworks[..<frameworkEnd]).replacingOccurrences(of: ".framework", with: "")
                    components.append("[\(framework)]")
                }
            }

            // Determine file type
            if path.hasSuffix(".h") {
                components.append("Objective-C Header")
            } else if path.hasSuffix(".swift") || path.hasSuffix(".swiftinterface") {
                components.append("Swift Interface")
            } else if path.contains(".docarchive") {
                components.append("Documentation")
            }

            components.append(fileName)

            formatted.append("\(index + 1). \(components.joined(separator: " - "))")
            formatted.append("   Path: \(path)")
            formatted.append("")
        }

        return formatted.joined(separator: "\n")
    }

    private func formatCombinedResults(spotlightResults: [(path: String, score: Int)], headerResults: String, query: String, limit: Int) -> String {
        var output = ["Documentation search results for '\(query)':", ""]

        if !spotlightResults.isEmpty {
            output.append("## Spotlight Results")
            output.append("")
            let sorted = spotlightResults.sorted { $0.score > $1.score }.prefix(limit)
            output.append(formatSpotlightResults(results: sorted.map { $0.path }, query: query))
        }

        if !headerResults.contains("No documentation") {
            output.append("")
            output.append("## SDK Header Results")
            output.append("")
            output.append(headerResults)
        }

        return output.joined(separator: "\n")
    }

    private func searchSymbolAcrossFrameworks(query: String, limit: Int) async -> [(framework: String, symbol: String, kind: String)] {
        // Get common frameworks to search
        let commonFrameworks = ["Foundation", "SwiftUI", "AppKit", "UIKit", "Combine", "CoreGraphics", "CoreFoundation"]
        var results: [(framework: String, symbol: String, kind: String)] = []

        for framework in commonFrameworks {
            if results.count >= limit { break }

            let sdkPath = getSDKPath()
            let frameworkPath = "\(sdkPath)/System/Library/Frameworks/\(framework).framework"

            guard FileManager.default.fileExists(atPath: frameworkPath) else { continue }

            // Try to extract symbols and search
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempDir) }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                process.arguments = [
                    "swift-symbolgraph-extract",
                    "-module-name", framework,
                    "-target", "arm64-apple-macos15.0",
                    "-sdk", sdkPath,
                    "-output-dir", tempDir.path,
                    "-minimum-access-level", "public"
                ]

                // Discard stderr to avoid potential deadlock (we don't need it here)
                process.standardError = FileHandle.nullDevice
                let outputPipe = Pipe()
                process.standardOutput = outputPipe

                try process.run()
                // Read output before waitUntilExit to avoid pipe buffer deadlock
                _ = outputPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let symbolGraphPath = tempDir.appendingPathComponent("\(framework).symbols.json")

                if FileManager.default.fileExists(atPath: symbolGraphPath.path) {
                    let data = try Data(contentsOf: symbolGraphPath)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let symbols = json["symbols"] as? [[String: Any]] {

                        for sym in symbols {
                            if let names = sym["names"] as? [String: Any],
                               let title = names["title"] as? String,
                               title.localizedCaseInsensitiveContains(query),
                               let kind = sym["kind"] as? [String: Any],
                               let kindName = kind["displayName"] as? String {

                                results.append((framework: framework, symbol: title, kind: kindName))

                                if results.count >= limit { break }
                            }
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return results
    }

    private func formatSymbolSearchResults(results: [(framework: String, symbol: String, kind: String)], query: String) -> String {
        var output = ["Found \(results.count) symbol(s) matching '\(query)' across frameworks:", ""]

        for (index, result) in results.enumerated() {
            output.append("\(index + 1). \(result.symbol)")
            output.append("   Framework: \(result.framework) - Kind: \(result.kind)")
            output.append("")
        }

        output.append("Tip: Use get_symbol_info with the module and symbol name for detailed information.")

        return output.joined(separator: "\n")
    }

    private func searchInSDKHeaders(query: String, limit: Int) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")

        let sdkPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks"

        process.arguments = [
            "-r", "-l", "-i",
            "--include=*.h",
            query,
            sdkPath
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        // Discard stderr to avoid potential deadlock (we don't need it)
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Read output before waitUntilExit to avoid pipe buffer deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: data, encoding: .utf8) ?? ""

            let lines = output.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .prefix(limit)

            if lines.isEmpty {
                return "No documentation found for '\(query)'. Try a different search term or check the symbol name."
            }

            // Format the results nicely
            var results: [String] = ["SDK header files containing '\(query)':"]
            for line in lines {
                // Extract framework name from path
                if let range = line.range(of: "/Frameworks/") {
                    let frameworkPart = String(line[range.upperBound...])
                    results.append("  - \(frameworkPart)")
                } else {
                    results.append("  - \(line)")
                }
            }

            return results.joined(separator: "\n")
        } catch {
            return "Error searching SDK headers: \(error.localizedDescription)"
        }
    }

    private func getSymbolInfo(module: String, symbol: String) async -> String {
        // First, try to find the symbol in the module's interface
        let sdkPath = getSDKPath()

        // Try Swift interface first
        let swiftInterfacePath = "\(sdkPath)/System/Library/Frameworks/\(module).framework/Modules/\(module).swiftmodule"

        // Check if it's a Swift module
        let fileManager = FileManager.default
        var swiftResult: String? = nil

        if fileManager.fileExists(atPath: swiftInterfacePath) {
            // Use swift-symbolgraph-extract for Swift modules
            swiftResult = await extractSymbolFromModule(module: module, symbol: symbol, sdkPath: sdkPath)

            // If we found an exact match in Swift, return it
            // Otherwise, also try Objective-C headers
            if let result = swiftResult, !result.contains("not found") && !result.contains("Did you mean") {
                // Check if this is actually an exact match by seeing if the title matches
                if result.contains("# \(symbol)\n") || result.contains("# \(symbol) ") {
                    return result
                }
            }
        }

        // Try Objective-C headers
        let headerPath = "\(sdkPath)/System/Library/Frameworks/\(module).framework/Headers"
        if fileManager.fileExists(atPath: headerPath) {
            let headerResult = await searchSymbolInHeaders(symbol: symbol, headerPath: headerPath, module: module)
            // Prefer Objective-C result if it's not "not found"
            if !headerResult.contains("not found") {
                return headerResult
            }
        }

        // Return Swift result if we have one, otherwise error
        if let result = swiftResult {
            return result
        }

        return "Module '\(module)' not found in SDK. Use list_frameworks to see available modules."
    }

    private func extractSymbolFromModule(module: String, symbol: String, sdkPath: String) async -> String {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = [
                "swift-symbolgraph-extract",
                "-module-name", module,
                "-target", "arm64-apple-macos15.0",
                "-sdk", sdkPath,
                "-output-dir", tempDir.path,
                "-minimum-access-level", "public"
            ]

            // Discard stdout/stderr to avoid deadlock - output goes to file, we check terminationStatus for errors
            process.standardError = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice

            try process.run()
            process.waitUntilExit()

            // Read the symbol graph JSON
            let symbolGraphPath = tempDir.appendingPathComponent("\(module).symbols.json")

            if FileManager.default.fileExists(atPath: symbolGraphPath.path) {
                let data = try Data(contentsOf: symbolGraphPath)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let symbols = json["symbols"] as? [[String: Any]] {

                    // Find the requested symbol - prioritize exact matches
                    var exactMatch: [String: Any]?
                    var partialMatch: [String: Any]?

                    for sym in symbols {
                        if let names = sym["names"] as? [String: Any],
                           let title = names["title"] as? String {

                            // Check for exact match first
                            if title == symbol || title.lowercased() == symbol.lowercased() {
                                exactMatch = sym
                                break
                            }

                            // Keep first partial match as fallback
                            if partialMatch == nil && title.localizedCaseInsensitiveContains(symbol) {
                                partialMatch = sym
                            }
                        }
                    }

                    // Use exact match if found, otherwise use partial match
                    if let foundSymbol = exactMatch ?? partialMatch {
                        if let names = foundSymbol["names"] as? [String: Any],
                           let title = names["title"] as? String {

                            var info: [String] = ["# \(title)"]

                            if let kind = foundSymbol["kind"] as? [String: Any],
                               let kindName = kind["displayName"] as? String {
                                info.append("**Kind:** \(kindName)")
                            }

                            if let declaration = foundSymbol["declarationFragments"] as? [[String: Any]] {
                                let declString = declaration.compactMap { $0["spelling"] as? String }.joined()
                                info.append("\n**Declaration:**\n```swift\n\(declString)\n```")
                            }

                            if let docComment = foundSymbol["docComment"] as? [String: Any],
                               let lines = docComment["lines"] as? [[String: Any]] {
                                let docText = lines.compactMap { $0["text"] as? String }.joined(separator: "\n")
                                info.append("\n**Documentation:**\n\(docText)")
                            }

                            return info.joined(separator: "\n")
                        }
                    }

                    // Symbol not found, list similar ones
                    let similar = symbols.compactMap { sym -> String? in
                        guard let names = sym["names"] as? [String: Any],
                              let title = names["title"] as? String,
                              title.localizedCaseInsensitiveContains(symbol.prefix(3)) else { return nil }
                        return title
                    }.prefix(10)

                    if !similar.isEmpty {
                        return "Symbol '\(symbol)' not found in \(module). Did you mean one of these?\n" + similar.map { "  - \($0)" }.joined(separator: "\n")
                    }
                }
            }

            // If symbolgraph extraction failed, fallback to header search
            if process.terminationStatus != 0 {
                let headerPath = "\(sdkPath)/System/Library/Frameworks/\(module).framework/Headers"
                return await searchSymbolInHeaders(symbol: symbol, headerPath: headerPath, module: module)
            }

            return "Symbol '\(symbol)' not found in module '\(module)'."

        } catch {
            return "Error extracting symbol info: \(error.localizedDescription)"
        }
    }

    private func searchSymbolInHeaders(symbol: String, headerPath: String, module: String) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        process.arguments = [
            "-r", "-n", "-A", "5", "-B", "2",
            "--include=*.h",
            symbol,
            headerPath
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        // Discard stderr to avoid potential deadlock (we don't need it)
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Read output before waitUntilExit to avoid pipe buffer deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: data, encoding: .utf8) ?? ""

            if output.isEmpty {
                return "Symbol '\(symbol)' not found in \(module) headers."
            }

            // Truncate if too long
            let truncated = String(output.prefix(3000))
            let suffix = output.count > 3000 ? "\n... (truncated)" : ""

            return "Found '\(symbol)' in \(module) headers:\n\n```objc\n\(truncated)\(suffix)\n```"
        } catch {
            return "Error searching headers: \(error.localizedDescription)"
        }
    }

    private func listFrameworks(filter: String?) async -> String {
        let sdkPath = getSDKPath()
        let frameworksPath = "\(sdkPath)/System/Library/Frameworks"

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: frameworksPath)
            var frameworks = contents
                .filter { $0.hasSuffix(".framework") }
                .map { String($0.dropLast(".framework".count)) }
                .sorted()

            if let filter = filter, !filter.isEmpty {
                frameworks = frameworks.filter { $0.localizedCaseInsensitiveContains(filter) }
            }

            if frameworks.isEmpty {
                return "No frameworks found matching '\(filter ?? "")'."
            }

            return "Available frameworks (\(frameworks.count)):\n\n" + frameworks.map { "  - \($0)" }.joined(separator: "\n")
        } catch {
            return "Error listing frameworks: \(error.localizedDescription)"
        }
    }

    private func extractModuleSymbols(module: String, kind: String) async -> String {
        let sdkPath = getSDKPath()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = [
                "swift-symbolgraph-extract",
                "-module-name", module,
                "-target", "arm64-apple-macos15.0",
                "-sdk", sdkPath,
                "-output-dir", tempDir.path,
                "-minimum-access-level", "public"
            ]

            // Discard stdout/stderr to avoid potential deadlock (output goes to file)
            process.standardError = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice

            try process.run()
            process.waitUntilExit()

            let symbolGraphPath = tempDir.appendingPathComponent("\(module).symbols.json")

            guard FileManager.default.fileExists(atPath: symbolGraphPath.path) else {
                return "Could not extract symbols from '\(module)'. It may be an Objective-C only framework. Use get_symbol_info to search headers directly."
            }

            let data = try Data(contentsOf: symbolGraphPath)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let symbols = json["symbols"] as? [[String: Any]] else {
                return "Failed to parse symbol graph for '\(module)'."
            }

            // Filter and group symbols by kind
            var grouped: [String: [String]] = [:]

            for sym in symbols {
                guard let names = sym["names"] as? [String: Any],
                      let title = names["title"] as? String,
                      let kindInfo = sym["kind"] as? [String: Any],
                      let kindIdentifier = kindInfo["identifier"] as? String else { continue }

                // Map kind identifiers to simple names
                let simpleKind: String
                if kindIdentifier.contains("struct") { simpleKind = "struct" }
                else if kindIdentifier.contains("class") { simpleKind = "class" }
                else if kindIdentifier.contains("enum") { simpleKind = "enum" }
                else if kindIdentifier.contains("protocol") { simpleKind = "protocol" }
                else if kindIdentifier.contains("func") || kindIdentifier.contains("method") { simpleKind = "func" }
                else if kindIdentifier.contains("var") || kindIdentifier.contains("property") { simpleKind = "var" }
                else if kindIdentifier.contains("typealias") { simpleKind = "typealias" }
                else { simpleKind = "other" }

                // Apply filter
                if kind != "all" && simpleKind != kind { continue }

                grouped[simpleKind, default: []].append(title)
            }

            if grouped.isEmpty {
                return "No symbols found in '\(module)' matching kind '\(kind)'."
            }

            var result: [String] = ["# Symbols in \(module)"]

            let orderedKinds = ["protocol", "class", "struct", "enum", "typealias", "func", "var", "other"]
            for k in orderedKinds {
                if let syms = grouped[k], !syms.isEmpty {
                    result.append("\n## \(k.capitalized)s (\(syms.count))")
                    result.append(syms.sorted().prefix(50).map { "  - \($0)" }.joined(separator: "\n"))
                    if syms.count > 50 {
                        result.append("  ... and \(syms.count - 50) more")
                    }
                }
            }

            return result.joined(separator: "\n")

        } catch {
            return "Error extracting module symbols: \(error.localizedDescription)"
        }
    }

    private func getSDKPath() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--show-sdk-path"]

        let pipe = Pipe()
        process.standardOutput = pipe
        // Discard stderr to avoid potential deadlock (we don't need it)
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Read output before waitUntilExit to avoid pipe buffer deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !output.isEmpty {
                return output
            }
        } catch {}

        // Default fallback
        return "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    }
}

// MARK: - Entry Point

@main
struct XcodeDocsMCPApp {
    static func main() async {
        let server = MCPServer()
        await server.run()
    }
}
