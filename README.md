# graphql-mcp

Expose a [GraphQL-Ruby](https://graphql-ruby.org) schema as an [MCP](https://modelcontextprotocol.io) server, so AI assistants can call your queries and mutations as tools.

> **Status:** in development. The published 0.1.0 is an empty placeholder; the first usable release will be 0.2.0.

## Planned usage

```ruby
# config/routes.rb
mount GraphQLMCP.from_schema(MySchema), at: "/mcp"
```

- MCP tools, with input and output schemas, are generated from the schema's queries, mutations and types
- Every tool call runs through the original schema, so resolvers, authorization and validation behave as they do over GraphQL
- The first version selects scalar and enum output fields automatically
- The application provides the authentication context and chooses which operations are exposed

Installation, configuration, supported types and limitations will be documented here before the first release.

## Sorbet

The gem ships RBI signatures in `rbi/`. Running `bin/tapioca gem` in an application imports them, so Sorbet knows the gem's types without a separate RBI.

## Development

```bash
mise install    # Ruby version from mise.toml
bundle install
bundle exec rake    # tests, RuboCop and Sorbet
```

Tests run against a real Rails application with a GraphQL schema in `test/dummy`, backed by an in-memory SQLite database.

## License

Available as open source under the terms of the [MIT License](LICENSE.txt).
