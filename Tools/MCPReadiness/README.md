# Independent public JSON/JSONSchema consumer

This package qualifies the actual public interface for downstream Swift-MCP-Server
work without importing the server, private meters or regex. It copies the frozen
schema/vectors byte for byte from pinned upstream qualification inputs and retains their full
license/NOTICE/provenance under Sources/MCPReadinessKit/Resources.

```sh
swift test --package-path Tools/MCPReadiness
swift run --package-path Tools/MCPReadiness MCPReadiness /tmp/mcp-readiness.json
```

Requires macOS/SDK 27+, Swift tools/compiler 6.4+ and Swift language mode 6.
The twenty vectors select one of four definitions through explicit $ref wrappers.
The unrooted 155-definition document is never counted as instance qualification.
Negative verdicts and thrown operational errors are recorded separately. Exact
IDs/lexemes, scalar keys, presence, raw tool schema, unknown annotations and bounded
inspection are checked. Three Swift Testing functions also prove checked public
cumulative budgets and terminal failure. See the
[actual interface note](../../Documentation/ConsumerInterface.md).

The executable emits infrastructure-only JSON receipts using Foundation.JSONEncoder;
all qualified value parsing/writing/schema work uses native public JSON APIs.
The source contains no MCP session, HTTP or protocol implementation. Root package
dependencies remain empty; this development package depends only on the local package.
