# frozen_string_literal: true

require "test_helper"

# Runs equivalent operations through GraphQL and through MCP and compares the results
class ParityTest < ActionDispatch::IntegrationTest
  POST_FIELDS = "id createdAt title body status rating featured wordCount publishedAt scheduledOn tags metadata"

  setup do
    @author = create_user(name: "Ada")
    @other = create_user(name: "Grace")
    travel_to Time.utc(2026, 11, 2, 12)
  end

  test "query with scalar, enum, null and nested object fields" do
    record = create_post(author: @author, body: "one two three", rating: 4.5, featured: true)
    create_post(author: @author, title: "Empty", status: :draft)

    graphql_result = graphql("query($id: ID!) { post(id: $id) { #{POST_FIELDS} author { id createdAt name } } }", variables: { id: record.id }, user: @author)
    mcp_result = call_tool("post", { id: record.id.to_s }, user: @author)

    assert_same_result graphql_result, mcp_result
    assert_equal "PUBLISHED", mcp_result.dig("structuredContent", "post", "status")
    assert_equal "Ada", mcp_result.dig("structuredContent", "post", "author", "name")
  end

  test "null fields stay null" do
    record = create_post(author: @author, title: "Bare")

    graphql_result = graphql("query($id: ID!) { post(id: $id) { #{POST_FIELDS} author { id createdAt name } } }", variables: { id: record.id }, user: @author)
    mcp_result = call_tool("post", { id: record.id.to_s }, user: @author)

    assert_same_result graphql_result, mcp_result
    assert_nil mcp_result.dig("structuredContent", "post", "body")
    assert_nil mcp_result.dig("structuredContent", "post", "rating")
  end

  test "connection with enum filter and cursor pagination" do
    3.times { |index| create_post(author: @author, title: "Live #{index}") }
    create_post(author: @author, title: "Draft", status: :draft)
    query = <<~GRAPHQL
      query($first: Int, $after: String, $status: PostStatusEnum) {
        posts(first: $first, after: $after, status: $status) {
          nodes { #{POST_FIELDS} author { id createdAt name } }
          pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
        }
      }
    GRAPHQL

    first_page = call_tool("posts", { first: 2, status: "PUBLISHED" }, user: @author)
    assert_same_result graphql(query, variables: { first: 2, status: "PUBLISHED" }, user: @author), first_page
    assert_equal true, first_page.dig("structuredContent", "posts", "pageInfo", "hasNextPage")

    cursor = first_page.dig("structuredContent", "posts", "pageInfo", "endCursor")
    second_page = call_tool("posts", { first: 2, after: cursor, status: "PUBLISHED" }, user: @author)
    assert_same_result graphql(query, variables: { first: 2, after: cursor, status: "PUBLISHED" }, user: @author), second_page
    assert_equal ["Live 0"], second_page.dig("structuredContent", "posts", "nodes").pluck("title")
  end

  test "resolvers receive the application context" do
    graphql_result = graphql("{ viewer { id createdAt name } }", user: @other)
    mcp_result = call_tool("viewer", user: @other)

    assert_same_result graphql_result, mcp_result
    assert_equal "Grace", mcp_result.dig("structuredContent", "viewer", "name")
  end

  test "execution errors" do
    graphql_result = graphql("query($id: ID!) { post(id: $id) { id } }", variables: { id: "0" }, user: @author)
    mcp_result = call_tool("post", { id: "0" }, user: @author)

    assert_same_result graphql_result, mcp_result
    assert_equal "Post not found", mcp_result.dig("content", 0, "text")
  end

  test "invalid enum values fail GraphQL validation" do
    query = "query($status: PostStatusEnum) { posts(status: $status) { nodes { id } } }"

    assert_same_result graphql(query, variables: { status: "DELETED" }, user: @author),
                       call_tool("posts", { status: "DELETED" }, user: @author)
  end

  test "missing required input fields fail GraphQL validation" do
    query = "mutation($input: PostInput!) { createPost(input: $input) { errors } }"
    input = { body: "no title" }

    assert_same_result graphql(query, variables: { input: }, user: @author),
                       call_tool("createPost", { input: }, user: @author)
    assert_equal 0, Post.count
  end

  test "missing required top-level arguments are rejected by the MCP SDK" do
    result = call_tool("post", {}, user: @author)

    assert_equal true, result["isError"]
    assert_match(/id/, result.dig("content", 0, "text"))
  end

  test "authorization errors" do
    record = create_post(author: @author)
    query = "mutation($id: ID!) { deletePost(id: $id) { deletedId } }"

    assert_same_result graphql(query, variables: { id: record.id }, user: @other),
                       call_tool("deletePost", { id: record.id.to_s }, user: @other)
    assert Post.exists?(record.id)
  end

  test "mutations create the same record from the same starting data" do
    query = "mutation($input: PostInput!) { createPost(input: $input) { post { #{POST_FIELDS} author { id createdAt name } } errors } }"
    input = { title: "New", body: "a b c", status: "PUBLISHED", rating: 5.0 }

    graphql_result = rolled_back { graphql(query, variables: { input: }, user: @author) }
    assert_equal 0, Post.count

    mcp_result = call_tool("createPost", { input: }, user: @author)

    assert_same_result graphql_result, mcp_result
    assert_equal ["New"], @author.posts.pluck(:title)
    assert_equal Time.current, @author.posts.first.published_at
  end

  test "mutations update the same record from the same starting data" do
    record = create_post(author: @author, title: "Old", status: :draft)
    query = "mutation($id: ID!, $input: PostInput!) { updatePost(id: $id, input: $input) { post { #{POST_FIELDS} author { id createdAt name } } errors } }"
    arguments = { id: record.id.to_s, input: { title: "Renamed", featured: true } }

    graphql_result = rolled_back { graphql(query, variables: arguments, user: @author) }
    assert_equal "Old", record.reload.title

    mcp_result = call_tool("updatePost", arguments, user: @author)

    assert_same_result graphql_result, mcp_result
    assert_equal ["Renamed", true], record.reload.values_at(:title, :featured)
  end

  test "model validation errors leave the data unchanged" do
    query = "mutation($input: PostInput!) { createPost(input: $input) { post { id } errors } }"
    input = { title: "x" * 101, rating: 9.0 }

    graphql_result = graphql(query, variables: { input: }, user: @author)
    mcp_result = call_tool("createPost", { input: }, user: @author)

    assert_equal graphql_result.dig("data", "createPost", "errors"), mcp_result.dig("structuredContent", "createPost", "errors")
    assert_equal false, mcp_result["isError"]
    assert_equal 0, Post.count
  end

  test "mutations delete the same record from the same starting data" do
    record = create_post(author: @author)
    query = "mutation($id: ID!) { deletePost(id: $id) { deletedId } }"

    graphql_result = rolled_back { graphql(query, variables: { id: record.id }, user: @author) }
    assert Post.exists?(record.id)

    mcp_result = call_tool("deletePost", { id: record.id.to_s }, user: @author)

    assert_same_result graphql_result, mcp_result
    refute Post.exists?(record.id)
  end
end
