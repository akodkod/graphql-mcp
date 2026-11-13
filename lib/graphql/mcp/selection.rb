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
      entries = @types.possible_types(type).to_h { |member| [member, selected_entries(member, depth)] }
      aliases = union_aliases(entries)
      members = entries.map do |member, selections|
        graphql, schema = render_entries(selections, aliases: aliases.fetch(member))
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

    # Distinct response keys prevent return-type conflicts across mutually exclusive fragments
    def union_aliases(entries)
      fields = entries.transform_values { |selections| selections.map(&:first) }
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

    def composite(type, depth)
      render_entries(selected_entries(type, depth))
    end

    def selected_entries(type, depth)
      connection = connection?(type)

      @types.fields(type).filter_map do |field|
        next if required_arguments?(field)
        next if connection && field.graphql_name == "edges" # Same records as `nodes`

        field_type = field.type.unwrap

        if !field_type.kind.leaf? && !connection && (field.type.list? || connection?(field_type) || depth.zero?)
          next
        end

        graphql, schema = output(field.type, connection ? depth : depth - 1)
        [field, graphql, schema] if schema
      end
    end

    def render_entries(entries, aliases: {})
      return [nil, nil] if entries.empty?

      graphql = entries.map do |field, selection, _|
        name = field.graphql_name
        response_field = aliases.key?(name) ? "#{aliases[name]}: #{name}" : name
        [response_field, selection].compact.join(" ")
      end

      properties = entries.to_h { |field, _, schema| [aliases.fetch(field.graphql_name, field.graphql_name), schema] }

      ["{ #{graphql.join(' ')} }", JSONSchema.object(properties)]
    end

    def required_arguments?(field)
      @types.arguments(field).any? { |argument| argument.type.non_null? && !argument.default_value? }
    end

    def connection?(type)
      type.kind.object? && type < GraphQL::Types::Relay::ConnectionBehaviors
    end
  end
end
