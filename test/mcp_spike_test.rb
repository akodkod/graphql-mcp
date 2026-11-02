# frozen_string_literal: true

require "test_helper"

# Spike: runs the same operations through GraphQL and through the MCP SDK endpoint
class MCPSpikeTest < ActionDispatch::IntegrationTest
  setup do
    @author = create_user(name: "Ada")
  end

  test "rejects requests without a valid token" do
    post "/mcp", params: rpc("tools/list").to_json, headers: mcp_headers

    assert_response :unauthorized
    assert_equal "Bearer", response.headers["www-authenticate"]
  end

  test "initialize reports the server" do
    result = mcp("initialize", protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" })

    assert_equal "dummy", result.dig("serverInfo", "name")
    assert result.dig("capabilities", "tools")
  end

  test "tools/list works without a session and exposes schemas" do
    tools = mcp("tools/list")["tools"].index_by { |tool| tool["name"] }

    assert_equal ["createPost", "post"], tools.keys.sort
    assert_equal ["id"], tools.dig("post", "inputSchema", "required")
    assert_equal true, tools.dig("post", "annotations", "readOnlyHint")
    assert_equal "object", tools.dig("post", "outputSchema", "type")
  end

  test "query result matches GraphQL" do
    record = create_post(author: @author, body: "one two", rating: 3.5)

    graphql_data = graphql(
      "query($id: ID!) { post(id: $id) { #{SpikeTools::POST_FIELDS} } }",
      variables: { id: record.id },
      user: @author,
    ).dig("data", "post")
    mcp_result = mcp("tools/call", name: "post", arguments: { id: record.id.to_s })

    assert_equal false, mcp_result["isError"]
    assert_equal graphql_data, mcp_result["structuredContent"]
  end

  test "GraphQL errors become tool errors" do
    result = mcp("tools/call", name: "post", arguments: { id: "0" })

    assert_equal true, result["isError"]
    assert_equal "Post not found", result.dig("content", 0, "text")
  end

  test "mutation matches GraphQL from the same starting data" do
    query = "mutation($input: PostInput!) { createPost(input: $input) { post { #{SpikeTools::POST_FIELDS} } errors } }"
    input = { title: "New", body: "a b c", status: "PUBLISHED" }

    graphql_data = rolled_back { graphql(query, variables: { input: }, user: @author).dig("data", "createPost") }
    assert_equal 0, Post.count

    mcp_result = mcp("tools/call", name: "createPost", arguments: { input: })

    # publishedAt holds the creation time, which differs between the two runs
    assert_equal without_time(graphql_data), without_time(mcp_result["structuredContent"])
    assert_equal ["New"], @author.posts.pluck(:title)
  end

  test "the SDK validates arguments before GraphQL sees them" do
    result = mcp("tools/call", name: "createPost", arguments: { input: { body: "no title" } })

    assert_equal true, result["isError"]
    refute_match(/PostInput/, result.dig("content", 0, "text"))
  end

  private

  def mcp_headers(user: nil)
    headers = { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
    headers["Authorization"] = "Bearer #{user.token}" if user
    headers
  end

  def rpc(method, params = {})
    { jsonrpc: "2.0", id: 1, method:, params: }
  end

  def mcp(method, user: @author, **params)
    post "/mcp", params: rpc(method, params).to_json, headers: mcp_headers(user:)
    assert_response :success

    body = JSON.parse(response.body)
    assert_nil body["error"], body["error"].inspect
    body["result"]
  end

  def rolled_back
    result = nil

    ActiveRecord::Base.transaction(requires_new: true) do
      result = yield
      raise ActiveRecord::Rollback
    end

    result
  end

  def without_time(payload)
    payload.merge("post" => payload["post"].except("publishedAt"))
  end
end
