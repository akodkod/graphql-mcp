# frozen_string_literal: true

require "json"
require "rack"

module GraphQLMCP
  # Serves the schema's operations as MCP tools over Streamable HTTP
  class RackApp
    attr_reader :tools

    # context: a callable that receives the Rack request and returns the GraphQL context, or nil to reject it with 401
    # allowed_hosts: Host header values accepted besides loopback, see the SDK's DNS rebinding protection
    def initialize(schema:, context:, name: schema.name.to_s, allowed_hosts: nil)
      @name = name
      @context = context
      @allowed_hosts = allowed_hosts
      @tools = Operations.new(schema).map(&:to_tool)

      # GraphQL validates arguments itself, so its errors reach clients unchanged
      @configuration = MCP::Configuration.new(validate_tool_call_arguments: false)
    end

    def call(env)
      graphql_context = @context.call(Rack::Request.new(env))
      return unauthorized unless graphql_context

      # The SDK passes context to tools only through the server, so a stateless server is built per request
      server = MCP::Server.new(
        name: @name,
        version: GraphQLMCP::VERSION,
        tools: @tools,
        server_context: { graphql_context: },
        configuration: @configuration,
      )

      transport = MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        enable_json_response: true,
        serve_subscriptions_listen: false,
        allowed_hosts: @allowed_hosts,
      )

      transport.call(env)
    end

    private

    def unauthorized
      body = JSON.generate(error: "Unauthorized")
      [401, { "content-type" => "application/json", "www-authenticate" => "Bearer" }, [body]]
    end
  end
end
