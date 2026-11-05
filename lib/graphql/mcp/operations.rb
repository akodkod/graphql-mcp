# frozen_string_literal: true

module GraphQLMCP
  # All root query and mutation fields of a schema that a request without application context can see
  class Operations
    include Enumerable

    def initialize(schema, depth: Operation::DEFAULT_DEPTH)
      @schema = schema
      @depth = depth

      # The visibility profile filters fields, arguments and enum values the same way real queries do,
      # including `visible?` checks that depend on which schema runs the query
      @types = GraphQL::Query.new(schema, "{ __typename }", context: {}).types
    end

    def each(&)
      operations.each(&)
    end

    private

    def operations
      @operations ||= begin
        operations = root_fields(@types.query_root, "query") + root_fields(@types.mutation_root, "mutation")

        duplicates = operations.group_by(&:name).select { |_, group| group.size > 1 }.keys
        raise Error, "Query and mutation fields share tool names: #{duplicates.join(', ')}" if duplicates.any?

        operations
      end
    end

    def root_fields(type, operation_type)
      return [] unless type

      @types.fields(type).map do |field|
        Operation.new(schema: @schema, field:, operation_type:, types: @types, depth: @depth)
      end
    end
  end
end
