# frozen_string_literal: true

require "test_helper"

# Checks how `depth` limits the nested objects tools return
class DepthTest < Minitest::Test
  def test_depth_zero_selects_only_the_records_own_fields
    assert_equal(
      "query($id: ID!) { post(id: $id) { id createdAt title body status rating featured wordCount publishedAt scheduledOn tags metadata } }",
      operation("post", depth: 0).query,
    )
  end

  def test_depth_one_adds_one_level_of_objects
    assert_match(/ author \{ id createdAt name \} \} \}\z/, operation("post", depth: 1).query)
  end

  def test_connections_keep_their_nodes_at_depth_zero
    query = operation("posts", depth: 0).query

    assert_match(/nodes \{ id createdAt title [^{}]* metadata \}/, query)
    assert_match(/pageInfo \{ hasNextPage/, query)
    refute_match(/author \{/, query)
  end

  def test_mutation_payloads_keep_their_records_at_depth_zero
    assert_equal(
      "mutation($input: PostInput!) { createPost(input: $input) { post { id createdAt title body status rating featured wordCount publishedAt scheduledOn tags metadata } errors } }",
      operation("createPost", depth: 0).query,
    )
  end

  def test_rejects_invalid_depths
    [-1, 1.5, "1"].each do |depth|
      error = assert_raises(ArgumentError) { GraphQLMCP.from_schema(DummySchema, context: -> (_request) { {} }, depth:) }
      assert_equal "depth must be a non-negative integer", error.message
    end
  end

  private

  def operation(name, depth:)
    GraphQLMCP::Operations.new(DummySchema, depth:).find { |operation| operation.name == name }
  end
end
