# Xcode Documentation MCP Server

A local MCP (Model Context Protocol) server that provides access to Apple's developer documentation and SDK symbols directly from your Xcode installation.

## Features

- **search_documentation** - Search Apple documentation using Spotlight and SDK headers
- **get_symbol_info** - Get detailed info about a specific symbol using swift-symbolgraph-extract
- **list_frameworks** - List all available Apple frameworks in the macOS SDK
- **extract_module_symbols** - Extract all public symbols from a Swift module

## Requirements

- macOS 14.0+
- Xcode installed (with command line tools)
- Swift 6.0+

## Installation

### Homebrew

```bash
brew tap krzyzanowskim/formulae
brew install xcode-docs-mcp
```

### Building from Source

```bash
git clone https://github.com/krzyzanowskim/XcodeDocsMCP.git
cd XcodeDocsMCP
swift build -c release
```

The binary will be at `.build/release/xcode-docs-mcp`

## Configuration

### For Claude Code

The easiest way to add the server to Claude Code:

```bash
claude mcp add --scope user xcode-docs-mcp xcode-docs-mcp
```

### For Claude Desktop

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "xcode-docs": {
      "command": "xcode-docs-mcp"
    }
  }
}
```

## Usage Examples

Once installed, you can ask Claude:

- "List all SwiftUI protocols"
- "What is the declaration of URLSession in Foundation?"
- "Search for NSWindow in the documentation"
- "What frameworks are available that contain 'Kit'?"

## Tools

### search_documentation

Search Apple's developer documentation.

```json
{
  "query": "NSWindow",
  "limit": 20
}
```

### get_symbol_info

Get detailed information about a symbol.

```json
{
  "module": "SwiftUI",
  "symbol": "View"
}
```

### list_frameworks

List available frameworks.

```json
{
  "filter": "Swift"
}
```

### extract_module_symbols

Extract all symbols from a module.

```json
{
  "module": "Foundation",
  "kind": "struct"
}
```

Kind options: `struct`, `class`, `enum`, `protocol`, `func`, `var`, `all`

## How It Works

### Documentation Search (`search_documentation`)

The search uses a multi-strategy approach with intelligent ranking:

1. **Spotlight Search** - Uses enhanced `mdfind` queries to search:
   - Xcode's documentation cache
   - SDK headers and interfaces
   - Command line tools SDKs
   - Filters by content type (source code, headers, documentation)

2. **Relevance Scoring** - Results are ranked by:
   - Exact filename matches (highest priority)
   - Header/Swift interface files
   - Framework header directories
   - Symbol name prefixes
   - Documentation files
   - Framework name matches

3. **Smart Fallbacks**:
   - Falls back to SDK header grep search
   - Cross-framework symbol search in common frameworks
   - Helpful suggestions when no results found

4. **Rich Formatting** - Results include:
   - Framework name extraction
   - File type indicators (Objective-C/Swift/Documentation)
   - Emoji markers for quick identification
   - Full file paths for reference

### Symbol Information (`get_symbol_info`)

1. **Symbol Graph Extraction** - Uses `swift-symbolgraph-extract` to get detailed Swift symbol information directly from the SDK
2. **Header Search** - Falls back to searching Objective-C headers for symbols not available via Swift
3. **Exact Match Prioritization** - Prefers exact symbol matches over partial matches
