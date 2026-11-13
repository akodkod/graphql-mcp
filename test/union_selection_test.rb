# frozen_string_literal: true

require "test_helper"
require "json_schemer"

class UnionSelectionTest < Minitest::Test
  class StringValue < GraphQL::Schema::Object
    field :value, String, null: false
    field "StringValue_value", String, null: false, camelize: false, hash_key: :collision
  end

  class OtherStringValue < GraphQL::Schema::Object
    field :value, String, null: false
  end

  class IntValue < GraphQL::Schema::Object
    field :value, Integer, null: false
  end

  class ArgumentValue < GraphQL::Schema::Object
    field :value, String, null: false do
      argument :id, ID, required: true
    end
  end

  class ValueDetails < GraphQL::Schema::Object
    field :label, String, null: false
  end

  class ObjectValue < GraphQL::Schema::Object
    field :value, ValueDetails, null: false
  end

  class BaseUnion < GraphQL::Schema::Union
    def self.resolve_type(object, _context)
      object.fetch(:type)
    end
  end

  class CompatibleResult < BaseUnion
    possible_types StringValue, OtherStringValue
  end

  class ConflictingResult < BaseUnion
    possible_types StringValue, IntValue
  end

  class ArgumentLimitedResult < BaseUnion
    possible_types ArgumentValue, IntValue
  end

  class DepthLimitedResult < BaseUnion
    possible_types ObjectValue, IntValue
  end

  class Query < GraphQL::Schema::Object
    field :compatible, CompatibleResult, null: false
    field :conflicting, ConflictingResult, null: false
    field :argument_limited, ArgumentLimitedResult, null: false
    field :depth_limited, DepthLimitedResult, null: false

    def compatible
      context[:result]
    end

    def conflicting
      context[:result]
    end

    def argument_limited
      context[:result]
    end

    def depth_limited
      context[:result]
    end
  end

  class Schema < GraphQL::Schema
    query Query
    allow_legacy_invalid_return_type_conflicts false
  end

  def test_compatible_selected_fields_keep_their_response_keys
    operation = operation("compatible")

    assert_includes operation.query, "... on StringValue { value StringValue_value }"
    assert_includes operation.query, "... on OtherStringValue { value }"
    assert_member(
      operation,
      { type: StringValue, value: "text", collision: "kept" },
      { "__typename" => "StringValue", "value" => "text", "StringValue_value" => "kept" },
    )
    assert_member(
      operation,
      { type: OtherStringValue, value: "other" },
      { "__typename" => "OtherStringValue", "value" => "other" },
    )
  end

  def test_conflicting_selected_fields_preserve_existing_alias_collisions
    operation = operation("conflicting")

    assert_includes operation.query, "... on StringValue { StringValue_value_: value StringValue_value }"
    assert_includes operation.query, "... on IntValue { IntValue_value: value }"
    assert_member(
      operation,
      { type: StringValue, value: "text", collision: "kept" },
      { "__typename" => "StringValue", "StringValue_value_" => "text", "StringValue_value" => "kept" },
    )
    assert_member(
      operation,
      { type: IntValue, value: 42 },
      { "__typename" => "IntValue", "IntValue_value" => 42 },
    )
  end

  def test_fields_requiring_arguments_do_not_cause_aliases
    operation = operation("argumentLimited")

    assert_member(operation, { type: ArgumentValue }, { "__typename" => "ArgumentValue" })
    assert_member(operation, { type: IntValue, value: 42 }, { "__typename" => "IntValue", "value" => 42 })
    assert_includes operation.query, "... on IntValue { value }"
    refute_includes operation.query, "... on ArgumentValue"
  end

  def test_depth_skipped_fields_do_not_cause_aliases
    shallow = operation("depthLimited", depth: 0)

    assert_member(shallow, { type: ObjectValue, value: { label: "Nested" } }, { "__typename" => "ObjectValue" })
    assert_member(shallow, { type: IntValue, value: 42 }, { "__typename" => "IntValue", "value" => 42 })
    assert_includes shallow.query, "... on IntValue { value }"
    refute_includes shallow.query, "... on ObjectValue"

    deep = operation("depthLimited", depth: 1)

    assert_member(
      deep,
      { type: ObjectValue, value: { label: "Nested" } },
      { "__typename" => "ObjectValue", "ObjectValue_value" => { "label" => "Nested" } },
    )
    assert_member(deep, { type: IntValue, value: 42 }, { "__typename" => "IntValue", "IntValue_value" => 42 })
    assert_includes deep.query, "... on ObjectValue { ObjectValue_value: value { label } }"
    assert_includes deep.query, "... on IntValue { IntValue_value: value }"
  end

  private

  def operation(name, depth: 1)
    GraphQLMCP::Operations.new(Schema, depth:).find { |candidate| candidate.name == name }
  end

  def assert_member(operation, result, expected)
    response = operation.call({}, context: { result: })
    output_schema = JSON.parse(JSON.generate(operation.output_schema))
    branches = output_schema.dig("properties", operation.name, "anyOf")
    member_schema = branches.find { |branch| branch.dig("properties", "__typename", "const") == expected.fetch("__typename") }

    refute response.error?, response.to_h.inspect
    assert_equal({ operation.name => expected }, response.structured_content)
    assert JSONSchemer.schema(output_schema).valid?(response.structured_content)
    assert_equal expected.keys.sort, member_schema.fetch("properties").keys.sort
  end
end
