# frozen_string_literal: true

require "graphql"
require "mcp"
require_relative "mcp/version"
require_relative "mcp/json_schema"
require_relative "mcp/selection"
require_relative "mcp/operation"
require_relative "mcp/operations"
require_relative "mcp/rack_app"

module GraphQLMCP
  class Error < StandardError; end

  # Builds a Rack app that serves the schema's queries and mutations as MCP tools:
  #
  #   mount GraphQLMCP.from_schema(MySchema, context: ->(request) { { current_user: ... } }), at: "/mcp"
  def self.from_schema(schema, **)
    RackApp.new(schema:, **)
  end
end
