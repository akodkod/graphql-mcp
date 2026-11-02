# frozen_string_literal: true

require "json"
require "mcp"
require "rack"

# Spike: evaluates the official MCP SDK as the protocol layer. Not part of the public API
module GraphQLMCP
  module Spike
    # The SDK passes context to tools only through the server, so a stateless server is built per request
    class RackApp
      def initialize(name:, tools:, context:, allowed_hosts: nil)
        @name = name
        @tools = tools
        @context = context
        @allowed_hosts = allowed_hosts
      end

      def call(env)
        graphql_context = @context.call(Rack::Request.new(env))
        return unauthorized unless graphql_context

        server = MCP::Server.new(
          name: @name,
          version: GraphQLMCP::VERSION,
          tools: @tools,
          server_context: { graphql_context: },
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

    # Builds an MCP tool that runs a fixed GraphQL operation and returns the root field's data
    def self.operation_tool(schema:, name:, query:, field:, **tool_options)
      read_only = query.lstrip.start_with?("query")

      MCP::Tool.define(
        name:,
        annotations: { read_only_hint: read_only, destructive_hint: !read_only },
        **tool_options,
      ) do |server_context:, **arguments|
        # The SDK symbolizes argument keys, but GraphQL variables are keyed by strings
        variables = JSON.parse(JSON.generate(arguments))
        result = schema.execute(query, variables:, context: server_context[:graphql_context]).to_h

        if result["errors"]
          messages = result["errors"].map { |error| error["message"] }
          MCP::Tool::Response.new([type: "text", text: messages.join("\n")], error: true)
        else
          data = result.dig("data", field)
          MCP::Tool::Response.new([type: "text", text: JSON.generate(data)], structured_content: data)
        end
      end
    end
  end
end
