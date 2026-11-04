# frozen_string_literal: true

require "test_helper"

# Checks that `only` and `except` decide which operations become tools
class OperationSelectionTest < Minitest::Test
  ALL_TOOLS = ["createPost", "deletePost", "post", "posts", "updatePost", "viewer"].freeze

  def test_exposes_every_operation_by_default
    assert_equal ALL_TOOLS, tool_names(app)
  end

  def test_only_exposes_the_listed_operations
    assert_equal ["post", "posts"], tool_names(app(only: ["post", "posts"]))
  end

  def test_except_leaves_out_the_listed_operations
    assert_equal ["post", "posts", "viewer"], tool_names(app(except: [:createPost, :updatePost, :deletePost]))
  end

  def test_left_out_operations_cannot_be_called
    body = rpc(app(only: ["post"]), "tools/call", name: "createPost", arguments: { input: { title: "x" } })

    assert_equal "Tool not found: createPost", body.dig("error", "data")
  end

  def test_rejects_only_and_except_together
    error = assert_raises(ArgumentError) { app(only: ["post"], except: ["posts"]) }

    assert_equal "Pass either only: or except:, not both", error.message
  end

  def test_rejects_unknown_names_with_a_suggestion
    error = assert_raises(GraphQLMCP::Error) { app(only: ["post", "create_post", "nothing"]) }

    assert_equal "Unknown or hidden operations: create_post (did you mean createPost?), nothing", error.message
  end

  private

  def app(**)
    GraphQLMCP.from_schema(DummySchema, context: -> (_request) { {} }, **)
  end

  def tool_names(app)
    rpc(app, "tools/list").dig("result", "tools").pluck("name").sort
  end

  def rpc(app, method, **params)
    request = Rack::MockRequest.new(app)
    response = request.post(
      "/",
      input: { jsonrpc: "2.0", id: 1, method:, params: }.to_json,
      "CONTENT_TYPE" => "application/json",
      "HTTP_ACCEPT" => "application/json, text/event-stream",
    )

    JSON.parse(response.body)
  end
end
