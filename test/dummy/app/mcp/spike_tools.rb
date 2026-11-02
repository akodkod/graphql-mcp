# frozen_string_literal: true

# Hand-written tools for the MCP SDK spike. The gem will generate these from the schema
module SpikeTools
  POST_FIELDS = "id title body status rating featured wordCount publishedAt"

  POST_SCHEMA = {
    type: "object",
    properties: {
      id: { type: "string" },
      title: { type: "string" },
      body: { type: ["string", "null"] },
      status: { type: "string", enum: ["DRAFT", "PUBLISHED", "ARCHIVED"] },
      rating: { type: ["number", "null"] },
      featured: { type: "boolean" },
      wordCount: { type: "integer" },
      publishedAt: { type: ["string", "null"] },
    },
    required: ["id", "title", "status", "featured", "wordCount"],
  }.freeze

  def self.all
    [post, create_post]
  end

  def self.post
    GraphQLMCP::Spike.operation_tool(
      schema: DummySchema,
      name: "post",
      description: "Find a post by ID",
      query: "query($id: ID!) { post(id: $id) { #{POST_FIELDS} } }",
      field: "post",
      input_schema: { properties: { id: { type: "string" } }, required: ["id"] },
      output_schema: POST_SCHEMA,
    )
  end

  def self.create_post
    GraphQLMCP::Spike.operation_tool(
      schema: DummySchema,
      name: "createPost",
      description: "Create a post authored by the current user",
      query: "mutation($input: PostInput!) { createPost(input: $input) { post { #{POST_FIELDS} } errors } }",
      field: "createPost",
      input_schema: {
        properties: {
          input: {
            type: "object",
            properties: {
              title: { type: "string" },
              body: { type: "string" },
              status: { type: "string", enum: ["DRAFT", "PUBLISHED", "ARCHIVED"] },
              rating: { type: "number" },
              featured: { type: "boolean" },
            },
            required: ["title"],
          },
        },
        required: ["input"],
      },
    )
  end
end
