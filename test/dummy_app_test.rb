# frozen_string_literal: true

require "test_helper"

# Checks that the dummy Rails app and its schema behave as expected,
# so later GraphQL vs MCP comparisons rest on a working baseline
class DummyAppTest < ActionDispatch::IntegrationTest
  POST_FIELDS = "id title body status rating featured wordCount publishedAt"

  setup do
    @author = create_user(name: "Ada")
    @other = create_user(name: "Grace")
  end

  test "query returns scalar and enum fields" do
    post = create_post(author: @author, title: "Hello", body: "one two three", rating: 4.5, featured: true)

    result = graphql("query($id: ID!) { post(id: $id) { #{POST_FIELDS} } }", variables: { id: post.id })

    assert_nil result["errors"]
    assert_equal(
      {
        "id" => post.id.to_s,
        "title" => "Hello",
        "body" => "one two three",
        "status" => "PUBLISHED",
        "rating" => 4.5,
        "featured" => true,
        "wordCount" => 3,
        "publishedAt" => nil,
      },
      result.dig("data", "post"),
    )
  end

  test "connection filters by enum argument" do
    create_post(author: @author, title: "Live", status: :published)
    create_post(author: @author, title: "Draft", status: :draft)

    result = graphql("{ posts(status: PUBLISHED) { nodes { title status } pageInfo { hasNextPage } } }")

    assert_equal ["title" => "Live", "status" => "PUBLISHED"], result.dig("data", "posts", "nodes")
    assert_equal false, result.dig("data", "posts", "pageInfo", "hasNextPage")
  end

  test "missing record returns an execution error" do
    result = graphql("{ post(id: 0) { id } }")

    assert_nil result.dig("data", "post")
    assert_equal ["Post not found"], result["errors"].pluck("message")
  end

  test "invalid enum value fails validation" do
    result = graphql("{ posts(status: DELETED) { nodes { id } } }")

    assert_nil result["data"]
    assert_match(/DELETED/, result["errors"].first["message"])
  end

  test "mutation requires authentication" do
    result = graphql(create_post_mutation, variables: { input: { title: "New" } })

    assert_equal ["Authentication required"], result["errors"].pluck("message")
    assert_equal 0, Post.count
  end

  test "mutation creates a record" do
    result = graphql(create_post_mutation, variables: { input: { title: "New", status: "PUBLISHED" } }, user: @author)

    assert_equal [], result.dig("data", "createPost", "errors")
    assert_equal "PUBLISHED", result.dig("data", "createPost", "post", "status")
    assert_equal ["New"], @author.posts.pluck(:title)
    assert_predicate @author.posts.first.published_at, :present?
  end

  test "mutation returns model validation errors" do
    result = graphql(create_post_mutation, variables: { input: { title: "x" * 101, rating: 9.0 } }, user: @author)

    assert_nil result.dig("data", "createPost", "post")
    assert_equal(
      ["Title is too long (maximum is 100 characters)", "Rating must be in 0..5"],
      result.dig("data", "createPost", "errors"),
    )
    assert_equal 0, Post.count
  end

  test "missing required input fails validation" do
    result = graphql(create_post_mutation, variables: { input: { body: "no title" } }, user: @author)

    assert_nil result["data"]
    assert_match(/title/, result["errors"].first["message"])
  end

  test "only the author can delete a post" do
    post = create_post(author: @author)
    mutation = "mutation($id: ID!) { deletePost(id: $id) { deletedId } }"

    denied = graphql(mutation, variables: { id: post.id }, user: @other)
    assert_equal ["Not authorized to change this post"], denied["errors"].pluck("message")
    assert Post.exists?(post.id)

    deleted = graphql(mutation, variables: { id: post.id }, user: @author)
    assert_equal post.id.to_s, deleted.dig("data", "deletePost", "deletedId")
    refute Post.exists?(post.id)
  end

  private

  def create_post_mutation
    <<~GRAPHQL
      mutation($input: PostInput!) {
        createPost(input: $input) {
          post { #{POST_FIELDS} }
          errors
        }
      }
    GRAPHQL
  end
end
