# graphql-mcp

Expose a [GraphQL-Ruby](https://graphql-ruby.org) schema as an [MCP](https://modelcontextprotocol.io) server, so AI assistants like Claude, ChatGPT or Cursor can call your queries and mutations as tools.

```ruby
# config/routes.rb
mount GraphQLMCP.from_schema(MySchema, context: ->(request) { ... }), at: "/mcp"
```

- Each root query and mutation becomes an MCP tool, with input and output schemas generated from its arguments and type
- Every call runs a GraphQL operation through your schema, so resolvers, authorization, validation and errors behave exactly as they do over GraphQL
- Your app authenticates the request and builds the GraphQL context
- You choose which operations are exposed and how deep their results go

## Installation

```ruby
# Gemfile
gem "graphql-mcp"
```

Requires Ruby 3.2+, `graphql` 2.4+ and Rack 2.2+. It uses the official [MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk) and serves the [Streamable HTTP](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports#streamable-http) transport.

## Usage

`GraphQLMCP.from_schema` returns a Rack app. Mount it in Rails, or run it from any Rack server:

```ruby
# config/routes.rb
mcp = GraphQLMCP.from_schema(
  MySchema,
  name: "my-app",
  context: ->(request) {
    token = request.get_header("HTTP_AUTHORIZATION").to_s.delete_prefix("Bearer ")
    user = User.find_by_api_token(token)
    user && { current_user: user }
  },
  allowed_hosts: ["api.example.com"],
)

Rails.application.routes.draw do
  post "graphql", to: "graphql#execute"
  mount mcp, at: "mcp"
end
```

Then connect an MCP client to it. For example, Claude Code:

```bash
claude mcp add --transport http my-app https://api.example.com/mcp \
  --header "Authorization: Bearer <token>"
```

### Options

| Option | Default | |
|---|---|---|
| `context:` | required | Callable that receives the `Rack::Request` and returns the GraphQL context. Return `nil` to reject the request with `401 Unauthorized` |
| `name:` | `schema.name` | Server name shown to clients |
| `only:` | all | Tool names to expose. Names are root field names as in GraphQL, like `createPost` |
| `except:` | none | Tool names to leave out. Pass `only:` or `except:`, not both |
| `depth:` | `1` | Levels of nested objects tools return, see [Output](#output) |
| `allowed_hosts:` | loopback only | `Host` header values to accept besides `localhost`. Needed in production, see [Security](#security) |

Unknown names in `only:` or `except:` raise at boot, with a suggestion for misspelled ones:

```
GraphQLMCP::Error: Unknown or hidden operations: create_post (did you mean createPost?)
```

## Tools

A root field like this one:

```ruby
field :post, Types::PostType, description: "Find a post by ID" do
  argument :id, ID, required: true
end
```

becomes a tool named `post`, described as `Find a post by ID`, that runs:

```graphql
query($id: ID!) {
  post(id: $id) {
    id createdAt title body status rating featured wordCount publishedAt scheduledOn tags metadata
    author { id createdAt name }
  }
}
```

- **Input schema:** the field's arguments as JSON Schema. Required arguments are required, nullable ones accept `null`, enums list their values, and input objects are expanded. A recursive input object is left open below its first level
- **Output schema:** the GraphQL `data` object, `{ "post": { ... } }`
- **Result:** `data` as structured content, plus the same JSON as text for clients that ignore structured content
- **Errors:** GraphQL errors, including argument validation, are returned as a tool error with their messages joined by newlines. Field errors in a mutation payload (like `errors: [String]`) are part of the result, as over GraphQL
- **Annotations:** queries are marked read-only, non-destructive and idempotent. Mutations are marked as not read-only and possibly destructive, which clients use to ask before running them

Write descriptions on your fields and arguments: they are what the assistant reads to decide which tool to call.

### Output

Every scalar and enum field is selected. `depth:` sets how many levels of nested objects are included:

- `depth: 0`: each record's own fields only, like `post { id title ... }`
- `depth: 1`: also the objects it points to, like `post { ... author { id name } }`

Some fields are not counted as a level, so they work at any depth:

- **Connections** select `nodes` and `pageInfo` (and `totalCount` if your connection has it) without using up a level. `edges` is skipped, since it holds the same records as `nodes`
- **Mutation payloads** always return their records, so `createPost` returns `post { ... }` even at `depth: 0`

These fields are skipped:

- Lists of objects and connections inside a record, like `user { posts }`. Expose them as their own root fields with filters instead
- Fields with required arguments
- Hidden fields (see [Visibility](#visibility))

Interfaces select their own fields. Unions select each member's fields with inline fragments, plus `__typename` to tell them apart.

Lower depth means smaller tool definitions, which assistants load into their context on every request. For a large schema, `depth: 0` with focused root fields is often the better trade.

### Types

| GraphQL | JSON Schema |
|---|---|
| `Int` | `integer` |
| `Float` | `number` |
| `String`, `ID`, `BigInt` | `string` |
| `Boolean` | `boolean` |
| `ISO8601DateTime`, `ISO8601Date`, `ISO8601Duration` | `string` with `date-time`, `date` or `duration` format |
| Enum | `string` with its values |
| List | `array` |
| Input object | `object` with its arguments |
| Other custom scalars, like `JSON` | any value |

Values are validated by GraphQL, not by the MCP SDK, so clients get the same errors as GraphQL clients.

## Visibility

Tools are built from the schema as seen with an empty context, using [GraphQL-Ruby's visibility](https://graphql-ruby.org/authorization/visibility). Fields, arguments, enum values and types hidden there, for example with `visible?` or a `hidden:` option, are left out of tools. To keep a field out of MCP, hide it the same way you would from GraphQL clients.

Visibility is decided once, at boot. Per-user visibility is not reflected in tool definitions, but every call still runs with the request's context, so authorization in resolvers applies as usual.

## Security

- **Authentication:** return `nil` from `context:` to reject a request. An MCP client sends the same headers on every request, so an API token in the `Authorization` header is the simplest setup. OAuth is not built in
- **Authorization:** tools run your resolvers with your context, so they can do exactly what a GraphQL client with the same context can. Expose mutations carefully, and consider limited-permission tokens for assistants
- **DNS rebinding protection:** the MCP SDK rejects requests whose `Host` header is not loopback. Pass your public host names in `allowed_hosts:`
- **Limits:** the schema's `max_depth`, `max_complexity` and page sizes apply. Rate limiting is up to your app, for example with Rack::Attack

## Limitations

- Subscriptions are not exposed
- Queries and mutations share one tool namespace, so a query and a mutation with the same name raise at boot
- One server serves the same tools to every client. Mount several apps with different `only:` lists for different sets
- The server is stateless: no sessions, server-sent notifications, resources or prompts
- A missing required top-level argument is rejected by the MCP SDK before GraphQL runs, so its message differs from GraphQL's

## Sorbet

The gem ships RBI signatures in `rbi/`. Running `bin/tapioca gem` in an application imports them, so Sorbet knows the gem's types without a separate RBI.

## Development

```bash
mise install    # Ruby version from mise.toml
bundle install
bundle exec rake    # tests, RuboCop and Sorbet
```

Tests run against a real Rails application with a GraphQL schema in `test/dummy`, backed by an in-memory SQLite database. They compare each tool's result with the same operation over GraphQL, and mutation tests start from the same data.

The suite has 61 tests and 247 assertions. A coverage measurement on November 13, 2026, using Ruby's built-in coverage tooling recorded **99.6% line coverage** (232/233) and **96.6% branch coverage** (86/89) across all Ruby files in `lib/`, excluding tests and the dummy app. Coverage is measured separately from the default Rake task.

To try the dummy app with an MCP client:

```bash
bundle exec puma test/dummy/config.ru -p 9292
claude mcp add --transport http dummy http://localhost:9292/mcp --header "Authorization: Bearer dev-token"
```

## License

Available as open source under the terms of the [MIT License](LICENSE.txt).
