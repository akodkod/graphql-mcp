# frozen_string_literal: true

module GraphQLMCP
  # Chooses the output fields of an operation and describes them as JSON Schema.
  #
  # Scalar and enum fields are always selected. Object fields go `depth` levels deep, so a mutation payload
  # like `{ post { ... } errors }` returns the post, not just the errors. Connections select `nodes` and
  # `pageInfo` without using up depth. Lists of objects, nested connections, unions, hidden fields and fields
  # with required arguments are skipped
  class Selection
    attr_reader :graphql, :json_schema

    def initialize(type, depth:, types:)
      @types = types
      @json_schemas = JSONSchema.new(types)
      @graphql, @json_schema = output(type, depth)
    end

    private

    # Returns the selection set (nil for leaves) and the JSON Schema of a possibly wrapped type
    def output(type, depth)
      inner = type.non_null? ? type.of_type : type
      graphql, schema = non_null_output(inner, depth)
      return [nil, nil] unless schema

      [graphql, JSONSchema.nullable(schema, !type.non_null?)]
    end

    def non_null_output(type, depth)
      if type.list?
        graphql, schema = output(type.of_type, depth)
        [graphql, schema && { type: "array", items: schema }]
      elsif type.kind.leaf?
        [nil, @json_schemas.leaf(type)]
      elsif type.kind.object? || type.kind.interface?
        composite(type, depth)
      else
        [nil, nil]
      end
    end

    def composite(type, depth)
      connection = connection?(type)

      entries = @types.fields(type).filter_map do |field|
        next if required_arguments?(field)
        next if connection && field.graphql_name == "edges" # Same records as `nodes`

        field_type = field.type.unwrap

        if !field_type.kind.leaf? && !connection && (field.type.list? || connection?(field_type) || depth.zero?)
          next
        end

        graphql, schema = output(field.type, connection ? depth : depth - 1)
        [field.graphql_name, graphql, schema] if schema
      end

      return [nil, nil] if entries.empty?

      graphql = entries.map { |name, selection, _| [name, selection].compact.join(" ") }.join(" ")
      properties = entries.to_h { |name, _, schema| [name, schema] }

      ["{ #{graphql} }", JSONSchema.object(properties)]
    end

    def required_arguments?(field)
      @types.arguments(field).any? { |argument| argument.type.non_null? && !argument.default_value? }
    end

    def connection?(type)
      type.kind.object? && type < GraphQL::Types::Relay::ConnectionBehaviors
    end
  end
end
