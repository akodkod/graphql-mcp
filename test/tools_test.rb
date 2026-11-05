# frozen_string_literal: true

require "test_helper"

# Checks the tools and schemas generated from the dummy GraphQL schema, as MCP clients see them
class ToolsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
  end

  test "rejects requests the application does not authenticate" do
    body = mcp("tools/list")

    assert_response :unauthorized
    assert_equal "Bearer", response.headers["www-authenticate"]
    assert_equal "Unauthorized", body["error"]
  end

  test "initialize reports the server" do
    body = mcp("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } }, user: @user)

    assert_equal "dummy", body.dig("result", "serverInfo", "name")
    assert_equal GraphQLMCP::VERSION, body.dig("result", "serverInfo", "version")
  end

  test "every root query and mutation field becomes a tool" do
    tools = list_tools(user: @user)

    assert_equal ["createPost", "deletePost", "node", "post", "posts", "search", "updatePost", "viewer"], tools.keys.sort
    assert_equal "Find a post by ID", tools.dig("post", "description")
    assert_equal "Create a post authored by the current user", tools.dig("createPost", "description")
  end

  test "queries are read-only and mutations are not" do
    tools = list_tools(user: @user)

    assert_equal(
      { "readOnlyHint" => true, "destructiveHint" => false, "idempotentHint" => true, "openWorldHint" => false },
      tools.dig("post", "annotations"),
    )
    assert_equal(
      { "readOnlyHint" => false, "destructiveHint" => true, "idempotentHint" => false, "openWorldHint" => false },
      tools.dig("createPost", "annotations"),
    )
  end

  test "input schema follows arguments, input objects, enums and nullability" do
    schema = list_tools(user: @user).dig("createPost", "inputSchema")
    input = schema.dig("properties", "input")

    assert_equal ["input"], schema["required"]
    assert_equal "object", input["type"]
    assert_equal ["title"], input["required"]
    assert_equal({ "type" => "string" }, input.dig("properties", "title"))
    assert_equal({ "type" => ["string", "null"] }, input.dig("properties", "body"))
    assert_equal({ "type" => ["number", "null"] }, input.dig("properties", "rating"))
    assert_equal ["DRAFT", "PUBLISHED", "ARCHIVED", nil], input.dig("properties", "status", "enum")
  end

  test "connection arguments are tool inputs" do
    properties = list_tools(user: @user).dig("posts", "inputSchema", "properties")

    assert_equal ["after", "authorId", "before", "filter", "first", "last", "status"], properties.keys.sort
    assert_equal ["integer", "null"], properties.dig("first", "type")
  end

  test "output schema selects scalar and enum fields and one level of objects" do
    post = list_tools(user: @user).dig("post", "outputSchema", "properties", "post")

    assert_equal ["object", "null"], post["type"]
    assert_equal ["id", "createdAt", "title", "body", "status", "rating", "featured", "wordCount", "publishedAt", "scheduledOn", "tags", "metadata", "author"], post["properties"].keys
    assert_equal({ "type" => ["string", "null"], "format" => "date-time" }, post.dig("properties", "publishedAt"))
    assert_equal ["id", "createdAt", "name"], post.dig("properties", "author", "properties").keys
  end

  test "hidden fields are not selected" do
    post = list_tools(user: @user).dig("post", "outputSchema", "properties", "post")

    refute_includes post["properties"].keys, "moderationNote"
    assert_match(/moderationNote/, graphql("{ post(id: 1) { moderationNote } }")["errors"].first["message"])
  end

  test "connections return nodes and page info but not edges" do
    posts = list_tools(user: @user).dig("posts", "outputSchema", "properties", "posts")

    assert_equal ["nodes", "pageInfo"], posts["properties"].keys.sort
    assert_equal ["hasNextPage", "hasPreviousPage", "startCursor", "endCursor"], posts.dig("properties", "pageInfo", "properties").keys
  end

  test "mutation payloads do not use up a level" do
    payload = list_tools(user: @user).dig("createPost", "outputSchema", "properties", "createPost")

    assert_equal ["post", "errors"], payload["properties"].keys
    assert_equal ["id", "createdAt", "name"], payload.dig("properties", "post", "properties", "author", "properties").keys
  end
end
