## [Unreleased]

- Rename the namespace to `GraphQLMCP`
- Ship Sorbet RBI signatures in `rbi/`
- Add a Rails dummy app with a GraphQL schema for tests
- Generate MCP tools from root query and mutation fields, with input and output schemas
- Serve them with `GraphQLMCP.from_schema`, executing every call through the GraphQL schema
- Choose the exposed operations with `only:` or `except:`. Unknown names fail at boot
- Ship Sorbet signatures for `GraphQLMCP.from_schema`
- Set how many levels of nested objects tools return with `depth:` (default 1). Mutation payloads do not use up a level

## [0.1.0] - 2026-10-28

- Reserve the gem name (empty placeholder release)
