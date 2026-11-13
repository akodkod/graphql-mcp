# frozen_string_literal: true

module GraphQLMCP
  # Chooses the output fields of an operation and describes them as JSON Schema.
  #
  # Scalar and enum fields are always selected. Object fields go `depth` levels deep, so at depth 1 a post
  # includes `author { ... }`, and at depth 0 only its own fields. Connections select `nodes` and
  # `pageInfo` without using up depth. Interfaces select their own fields, and unions select each member's
  # fields with `... on Member`. Lists of objects, nested connections, hidden fields and fields with required
  # arguments are skipped
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
      elsif type.kind.union?
        union(type, depth)
      else
        [nil, nil]
      end
    end

    # Each member's fields in an inline fragment, with `__typename` to tell the results apart
    def union(type, depth)
      possible_types = @types.possible_types(type)
      aliases = union_aliases(possible_types)
      members = possible_types.map do |member|
        graphql, schema = composite(member, depth, aliases: aliases.fetch(member))
        schema ||= JSONSchema.object({})

        schema = schema.merge(
          properties: { __typename: { const: member.graphql_name } }.merge(schema[:properties]),
          required: ["__typename", *schema[:required]],
        )
        [graphql && "... on #{member.graphql_name} #{graphql}", schema]
      end

      return [nil, nil] if members.empty?

      ["{ __typename #{members.filter_map(&:first).join(' ')} }", anyOf: members.map(&:last)]
    end

    # Distinct response keys prevent return-type conflicts across mutually exclusive fragments.
    def union_aliases(members)
      fields = members.to_h { |member| [member, @types.fields(member)] }
      by_name = fields.values.flatten.group_by(&:graphql_name)
      conflicts = by_name.select { |_, definitions| definitions.map { |field| field.type.to_type_signature }.uniq.size > 1 }
      used_names = by_name.keys

      fields.to_h do |member, definitions|
        aliases = definitions.each_with_object({}) do |field, result|
          next unless conflicts.key?(field.graphql_name)

          name = "#{member.graphql_name}_#{field.graphql_name}"
          name = "#{name}_" while used_names.include?(name)
          used_names << name
          result[field.graphql_name] = name
        end
        [member, aliases]
      end
    end

    def composite(type, depth, aliases: {})
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

      graphql = entries.map do |name, selection, _|
        field = aliases.key?(name) ? "#{aliases[name]}: #{name}" : name
        [field, selection].compact.join(" ")
      end.join(" ")
      properties = entries.to_h { |name, _, schema| [aliases.fetch(name, name), schema] }

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
