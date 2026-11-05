# frozen_string_literal: true

require "json"

module GraphQLMCP
  # One root query or mutation field, exposed as an MCP tool that runs a generated GraphQL operation
  class Operation
    DEFAULT_DEPTH = 1

    attr_reader :schema, :field, :operation_type

    # types: the schema's visibility profile, which decides the arguments and fields to expose
    # depth: levels of nested objects to select, see Selection
    def initialize(schema:, field:, operation_type:, types:, depth: DEFAULT_DEPTH)
      @schema = schema
      @field = field
      @operation_type = operation_type
      @types = types

      # A mutation payload only wraps the records it returns, so it does not use up a level
      @selection = Selection.new(field.type, depth: payload? ? depth + 1 : depth, types:)
    end

    def name
      field.graphql_name
    end

    def description
      field.description
    end

    def read_only?
      operation_type == "query"
    end

    def query
      @query ||= begin
        arguments = @types.arguments(field)
        variables = arguments.map { |argument| "$#{argument.graphql_name}: #{argument.type.to_type_signature}" }
        values = arguments.map { |argument| "#{argument.graphql_name}: $#{argument.graphql_name}" }

        signature = variables.any? ? "(#{variables.join(', ')})" : ""
        call = values.any? ? "(#{values.join(', ')})" : ""

        "#{operation_type}#{signature} { #{name}#{call} #{selection_set} }".squeeze(" ")
      end
    end

    def input_schema
      JSONSchema.new(@types).arguments(field)
    end

    # Matches the GraphQL `data` object, so tools return the same shape as the API
    def output_schema
      JSONSchema.object({ name => @selection.json_schema || {} })
    end

    # The SDK fills unset hints with the spec's cautious defaults (destructive, not idempotent),
    # which suit mutations but would mislabel queries
    def annotations
      if read_only?
        { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }
      else
        { read_only_hint: false, open_world_hint: false }
      end
    end

    def to_tool
      operation = self
      annotations = self.annotations

      MCP::Tool.define(
        name:,
        description:,
        input_schema:,
        output_schema:,
        annotations:,
      ) do |server_context:, **arguments|
        operation.call(arguments, context: server_context[:graphql_context])
      end
    end

    def call(arguments, context:)
      # The SDK passes symbol keys, but GraphQL variables are keyed by strings
      variables = JSON.parse(JSON.generate(arguments))
      result = schema.execute(query, variables:, context:).to_h

      if result["errors"]
        messages = result["errors"].map { |error| error["message"] }
        MCP::Tool::Response.new([type: "text", text: messages.join("\n")], error: true)
      else
        data = result["data"]
        MCP::Tool::Response.new([type: "text", text: JSON.generate(data)], structured_content: data)
      end
    end

    private

    def payload?
      resolver = field.resolver
      !resolver.nil? && resolver < GraphQL::Schema::Mutation
    end

    # A composite type with nothing to select still needs a selection set to be a valid query
    def selection_set
      return @selection.graphql if @selection.graphql
      return "" if field.type.unwrap.kind.leaf?

      "{ __typename }"
    end
  end
end
