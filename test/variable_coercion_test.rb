# frozen_string_literal: true

require "minitest/autorun"
require "graphql/mcp"

class VariableCoercionTest < Minitest::Test
  class Status < GraphQL::Schema::Enum
    value "ACTIVE"
  end

  class PersonInput < GraphQL::Schema::InputObject
    argument :name, String, required: true
    argument :status, Status, required: true
  end

  class Query < GraphQL::Schema::Object
    field :greeting, String, null: false do
      argument :name, String, required: true
    end

    field :people, GraphQL::Types::JSON, null: false do
      argument :primary, PersonInput, required: true
      argument :others, [PersonInput], required: true
    end

    field :echo, GraphQL::Types::JSON, null: false do
      argument :payload, GraphQL::Types::JSON, required: true
    end

    def greeting(name:)
      "Hello #{name}"
    end

    def people(primary:, others:)
      {
        "primary" => { "name" => primary[:name], "status" => primary[:status] },
        "others" => others.map { |person| { "name" => person[:name], "status" => person[:status] } },
      }
    end

    def echo(payload:)
      payload
    end
  end

  class Schema < GraphQL::Schema
    query Query
  end

  def test_top_level_arguments_accept_symbol_and_string_keys
    [{ name: "Ada" }, { "name" => "Ada" }].each do |arguments|
      assert_result "greeting", arguments, { "greeting" => "Hello Ada" }
    end
  end

  def test_nested_input_objects_and_lists_accept_symbol_and_string_keys
    variants = [
      { primary: { name: "Ada", status: "ACTIVE" }, others: [name: "Grace", status: "ACTIVE"] },
      { "primary" => { "name" => "Ada", "status" => "ACTIVE" }, "others" => ["name" => "Grace", "status" => "ACTIVE"] },
    ]
    expected = {
      "people" => {
        "primary" => { "name" => "Ada", "status" => "ACTIVE" },
        "others" => ["name" => "Grace", "status" => "ACTIVE"],
      },
    }

    variants.each { |arguments| assert_result "people", arguments, expected }
  end

  def test_json_scalar_preserves_nested_values_with_symbol_and_string_keys
    variants = [
      { payload: { nested: [enabled: true, count: 42, absent: nil], flags: [false, true], label: "kept" } },
      { "payload" => { "nested" => ["enabled" => true, "count" => 42, "absent" => nil], "flags" => [false, true], "label" => "kept" } },
    ]
    expected = {
      "echo" => { "nested" => ["enabled" => true, "count" => 42, "absent" => nil], "flags" => [false, true], "label" => "kept" },
    }

    variants.each { |arguments| assert_result "echo", arguments, expected }
  end

  private

  def assert_result(name, arguments, expected)
    original = Marshal.load(Marshal.dump(arguments))
    operation = GraphQLMCP::Operations.new(Schema).find { |candidate| candidate.name == name }
    response = operation.call(arguments, context: {})

    refute response.error?, response.to_h.inspect
    assert_equal expected, response.structured_content
    assert_equal original, arguments
  end
end
