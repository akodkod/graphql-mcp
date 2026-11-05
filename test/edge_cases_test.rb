# frozen_string_literal: true

require "test_helper"

# Custom scalars, lists, recursive inputs, interfaces and unions, through GraphQL and through MCP
class EdgeCasesTest < ActionDispatch::IntegrationTest
  POST_FIELDS = "id createdAt title body status rating featured wordCount publishedAt scheduledOn tags metadata author { id createdAt name }"

  setup do
    @author = create_user(name: "Ada")
    travel_to Time.utc(2026, 11, 5, 12)
  end

  test "JSON, date and list values round-trip through a mutation" do
    query = "mutation($input: PostInput!) { createPost(input: $input) { post { #{POST_FIELDS} } errors } }"
    input = {
      title: "Typed",
      tags: ["ruby", "mcp"],
      scheduledOn: "2026-12-01",
      metadata: { "source" => "assistant", "nested" => { "count" => 2, "flags" => [true, false] } },
    }

    graphql_result = rolled_back { graphql(query, variables: { input: }, user: @author) }
    mcp_result = call_tool("createPost", { input: }, user: @author)

    assert_same_result graphql_result, mcp_result
    post = mcp_result.dig("structuredContent", "createPost", "post")
    assert_equal ["ruby", "mcp"], post["tags"]
    assert_equal "2026-12-01", post["scheduledOn"]
    assert_equal input[:metadata], post["metadata"]
  end

  test "invalid custom scalar values fail GraphQL validation" do
    query = "mutation($input: PostInput!) { createPost(input: $input) { errors } }"
    input = { title: "Bad date", scheduledOn: "2026-13-45" }

    assert_same_result graphql(query, variables: { input: }, user: @author), call_tool("createPost", { input: }, user: @author)
    assert_equal 0, Post.count
  end

  test "custom scalars map to JSON Schema" do
    input = list_tools(user: @author).dig("createPost", "inputSchema", "properties", "input", "properties")

    assert_equal({}, input["metadata"])
    assert_equal({ "type" => ["string", "null"], "format" => "date" }, input["scheduledOn"])
    assert_equal({ "type" => ["array", "null"], "items" => { "type" => "string" } }, input["tags"])
  end

  test "list arguments of IDs and enums filter like GraphQL" do
    live = create_post(author: @author, title: "Live")
    draft = create_post(author: @author, title: "Draft", status: :draft)
    create_post(author: @author, title: "Old", status: :archived)
    filter = { idIn: [live.id.to_s, draft.id.to_s], statuses: ["PUBLISHED", "DRAFT"] }

    graphql_result = graphql("query($filter: PostFilter) { posts(filter: $filter) { nodes { title } } }", variables: { filter: }, user: @author)
    mcp_result = call_tool("posts", { filter: }, user: @author)

    assert_equal(graphql_result.dig("data", "posts", "nodes"), mcp_result.dig("structuredContent", "posts", "nodes").map { |node| node.slice("title") })
    assert_equal ["Draft", "Live"], mcp_result.dig("structuredContent", "posts", "nodes").pluck("title")
  end

  test "recursive inputs stay open below the first level and still work" do
    create_post(author: @author, title: "Keep")
    create_post(author: @author, title: "Draft one")
    filter = { not: { titleContains: "Draft", not: { titleContains: "one" } } }

    filter_schema = list_tools(user: @author).dig("posts", "inputSchema", "properties", "filter")
    assert_equal({}, filter_schema.dig("properties", "not"))

    graphql_result = graphql("query($filter: PostFilter) { posts(filter: $filter) { nodes { title } } }", variables: { filter: }, user: @author)
    mcp_result = call_tool("posts", { filter: }, user: @author)

    assert_equal(graphql_result.dig("data", "posts", "nodes"), mcp_result.dig("structuredContent", "posts", "nodes").map { |node| node.slice("title") })
    assert_equal ["Draft one", "Keep"], mcp_result.dig("structuredContent", "posts", "nodes").pluck("title")
  end

  test "interfaces select their own fields" do
    post = create_post(author: @author)
    query = "query($id: ID!) { node(id: $id) { id createdAt } }"

    assert_equal ["id", "createdAt"], list_tools(user: @author).dig("node", "outputSchema", "properties", "node", "properties").keys

    ["Post:#{post.id}", "User:#{@author.id}"].each do |id|
      assert_same_result graphql(query, variables: { id: }, user: @author), call_tool("node", { id: }, user: @author)
    end
  end

  test "unions select each member's fields" do
    create_post(author: @author, title: "Ada's notes")
    query = <<~GRAPHQL
      query($query: String!) {
        search(query: $query) {
          __typename
          ... on Post { #{POST_FIELDS} }
          ... on User { id createdAt name }
        }
      }
    GRAPHQL

    graphql_result = graphql(query, variables: { query: "Ada" }, user: @author)
    mcp_result = call_tool("search", { query: "Ada" }, user: @author)

    assert_same_result graphql_result, mcp_result
    assert_equal ["Post", "User"], mcp_result.dig("structuredContent", "search").pluck("__typename")

    members = list_tools(user: @author).dig("search", "outputSchema", "properties", "search", "items", "anyOf")
    assert_equal([{ "const" => "Post" }, { "const" => "User" }], members.map { |member| member.dig("properties", "__typename") })
  end
end
