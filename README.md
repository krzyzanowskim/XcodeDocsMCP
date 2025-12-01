# Xcode Documentation MCP Server

MCP server for querying Apple developer documentation and SDK symbols from your local Xcode installation.

## Tools

- `search_documentation` - Search documentation using Spotlight and SDK headers
- `get_symbol_info` - Get symbol details via swift-symbolgraph-extract
- `list_frameworks` - List available Apple frameworks
- `extract_module_symbols` - Extract public symbols from a module

## Requirements

- macOS 14.0+
- Xcode with command line tools
- Swift 6.0+

## Installation

```bash
brew tap krzyzanowskim/tap
brew install xcode-docs-mcp
```

Or build from source:

```bash
swift build -c release
```

## Configuration

Claude Code:
```bash
claude mcp add --scope user xcode-docs-mcp xcode-docs-mcp
```

Claude Desktop (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "xcode-docs": {
      "command": "xcode-docs-mcp"
    }
  }
}
```
