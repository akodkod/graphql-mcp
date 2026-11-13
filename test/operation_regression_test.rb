# frozen_string_literal: true

require "test_helper"
require "json_schemer"

class OperationRegressionTest < Minitest::Test
  class TextResult < GraphQL::Schema::Object
    field :value, String, null: false
    field "TextResult_value", String, null: false, camelize: false, hash_key: :collision
  end

  class NumberResult < GraphQL::Schema::Object
    field :value, Integer, null: false
  end

  class ArgumentResult < GraphQL::Schema::Object
    field :value, String, null: false do
      argument :id, ID, required: true
    end
  end

  class Container < GraphQL::Schema::Object
    field :label, String, null: false
    field :restricted, ArgumentResult, null: false
  end

  class Result < GraphQL::Schema::Union
    possible_types TextResult, NumberResult, ArgumentResult

    def self.resolve_type(object, _context)
      object.fetch(:type)
    end
  end

  class EmptyResult < GraphQL::Schema::Union
    possible_types ArgumentResult

    def self.resolve_type(_object, _context)
      ArgumentResult
    end
  end

  class Query < GraphQL::Schema::Object
    field :greeting, String, null: false do
      argument :name, String, required: true, default_value: "world"
    end
    field :results, [Result], null: false
    field :empty_result, EmptyResult, null: false
    field :nullable_result, Result, null: true
    field :empty_object, ArgumentResult, null: false
    field :container, Container, null: false

    def greeting(name:)
      "Hello #{name}"
    end

    def results
      [
        { type: TextResult, value: "text", collision: "kept" },
        { type: NumberResult, value: 42 },
        { type: ArgumentResult },
      ]
    end

    def empty_result
      {}
    end

    def nullable_result
      context[:result]
    end

    def empty_object
      {}
    end

    def container
      { label: "Visible", restricted: {} }
    end
  end

  class Schema < GraphQL::Schema
    query Query
    allow_legacy_invalid_return_type_conflicts false
  end

  class Mutation < GraphQL::Schema::Object
    field :greeting, String, null: false
  end

  class DuplicateNamesSchema < GraphQL::Schema
    query Query
    mutation Mutation
  end

  def test_defaulted_non_null_argument_can_be_omitted
    operation = operation("greeting")
    response = operation.call({}, context: {})

    refute response.error?, response.to_h.inspect
    assert_equal({ "greeting" => "Hello world" }, response.structured_content)
    assert JSONSchemer.schema(operation.input_schema).valid?({})
  end

  def test_defaulted_non_null_argument_rejects_explicit_null
    operation = operation("greeting")

    assert operation.call({ name: nil }, context: {}).error?
    refute JSONSchemer.schema(operation.input_schema).valid?({ "name" => nil })
    assert_equal({ "greeting" => "Hello Ada" }, operation.call({ name: "Ada" }, context: {}).structured_content)
  end

  def test_conflicting_union_fields_have_distinct_response_keys
    operation = operation("results")
    response = operation.call({}, context: {})

    refute response.error?, response.to_h.inspect
    text, number = response.structured_content.fetch("results")
    assert_equal "text", text.fetch("TextResult_value_")
    assert_equal "kept", text.fetch("TextResult_value")
    assert_equal 42, number.fetch("NumberResult_value")
    assert JSONSchemer.schema(operation.output_schema).valid?(response.structured_content)
  end

  def test_union_retains_typename_only_member
    operation = operation("results")
    response = operation.call({}, context: {})

    refute response.error?, response.to_h.inspect
    assert_equal({ "__typename" => "ArgumentResult" }, response.structured_content.fetch("results").last)
    assert JSONSchemer.schema(operation.output_schema).valid?(response.structured_content)
  end

  def test_union_with_only_typename_members
    operation = operation("emptyResult")
    response = operation.call({}, context: {})

    refute response.error?, response.to_h.inspect
    assert_equal({ "emptyResult" => { "__typename" => "ArgumentResult" } }, response.structured_content)
    assert JSONSchemer.schema(operation.output_schema).valid?(response.structured_content)
  end

  def test_nullable_union_accepts_null_and_populated_results
    operation = operation("nullableResult")
    validator = JSONSchemer.schema(operation.output_schema)

    [nil, { type: NumberResult, value: 42 }].each do |result|
      response = operation.call({}, context: { result: })
      expected = result && { "__typename" => "NumberResult", "NumberResult_value" => 42 }

      refute response.error?, response.to_h.inspect
      assert_equal({ "nullableResult" => expected }, response.structured_content)
      assert validator.valid?(response.structured_content)
    end
    refute validator.valid?({ "nullableResult" => { "__typename" => "Unknown" } })
  end

  def test_duplicate_query_and_mutation_names_are_rejected
    error = assert_raises(GraphQLMCP::Error) { GraphQLMCP::Operations.new(DuplicateNamesSchema).to_a }

    assert_equal "Query and mutation fields share tool names: greeting", error.message
  end

  def test_root_object_without_selectable_fields_falls_back_to_typename
    operation = operation("emptyObject")
    response = operation.call({}, context: {})

    assert_equal "query { emptyObject { __typename } }", operation.query
    refute response.error?, response.to_h.inspect
    assert_equal({ "emptyObject" => { "__typename" => "ArgumentResult" } }, response.structured_content)
    assert JSONSchemer.schema(operation.output_schema).valid?(response.structured_content)
  end

  def test_nested_object_without_selectable_fields_is_omitted
    operation = operation("container")
    response = operation.call({}, context: {})

    assert_equal "query { container { label } }", operation.query
    refute response.error?, response.to_h.inspect
    assert_equal({ "container" => { "label" => "Visible" } }, response.structured_content)
    assert_equal ["label"], operation.output_schema.dig(:properties, "container", :properties).keys
    assert JSONSchemer.schema(operation.output_schema).valid?(response.structured_content)
  end

  private

  def operation(name)
    GraphQLMCP::Operations.new(Schema).find { |operation| operation.name == name }
  end
end
