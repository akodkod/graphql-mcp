# frozen_string_literal: true

module GraphQLMCP
  # Maps GraphQL types to JSON Schema. Arguments and enum values come from `types`,
  # the schema's visibility profile, so hidden ones are left out
  class JSONSchema
    SCALARS = {
      "Int" => { type: "integer" },
      "Float" => { type: "number" },
      "String" => { type: "string" },
      "Boolean" => { type: "boolean" },
      "ID" => { type: "string" },
      "BigInt" => { type: "string" },
      "ISO8601DateTime" => { type: "string", format: "date-time" },
      "ISO8601Date" => { type: "string", format: "date" },
      "ISO8601Duration" => { type: "string", format: "duration" },
    }.freeze

    def self.object(properties, required = properties.keys)
      schema = { type: "object", properties: }
      schema[:required] = required if required.any?
      schema[:additionalProperties] = false
      schema
    end

    def self.nullable(schema, nullable)
      return schema if !nullable || schema.empty?

      schema = schema.dup
      schema[:type] = [*schema[:type], "null"] if schema[:type]
      schema[:enum] = [*schema[:enum], nil] if schema[:enum]
      schema
    end

    def initialize(types)
      @types = types
    end

    # Arguments of a field or input object, as an object schema
    def arguments(owner, seen = [])
      properties = {}
      required = []

      @types.arguments(owner).each do |argument|
        schema = input(argument.type, seen)
        schema = schema.merge(description: argument.description) if argument.description
        properties[argument.graphql_name] = schema
        required << argument.graphql_name if argument.type.non_null? && !argument.default_value?
      end

      self.class.object(properties, required)
    end

    # Scalar or enum. Unknown custom scalars accept any value
    def leaf(type)
      return { type: "string", enum: @types.enum_values(type).map(&:graphql_name) } if type.kind.enum?

      SCALARS.fetch(type.graphql_name, {})
    end

    private

    def input(type, seen)
      inner = type.non_null? ? type.of_type : type
      self.class.nullable(non_null_input(inner, seen), !type.non_null?)
    end

    def non_null_input(type, seen)
      return { type: "array", items: input(type.of_type, seen) } if type.list?
      return leaf(type) unless type.kind.input_object?

      # A recursive input object is left open instead of expanding forever
      seen.include?(type) ? {} : arguments(type, [*seen, type])
    end
  end
end
