# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "graphql/mcp"

require_relative "dummy/config/environment"
require "rails/test_help"

ActiveRecord::Migration.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

class ActionDispatch::IntegrationTest
  private

  def create_user(name: "Ada", token: SecureRandom.hex(8))
    User.create!(name:, email: "#{name.downcase}@example.com", token:)
  end

  def create_post(author:, title: "Hello", status: :published, **attributes)
    Post.create!(author:, title:, status:, **attributes)
  end

  def graphql(query, variables: {}, user: nil)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{user.token}" if user

    post("/graphql", params: { query:, variables: }.to_json, headers:)
    assert_response :success

    JSON.parse(response.body)
  end

  # Sends one JSON-RPC request to the MCP endpoint and returns the parsed response body
  def mcp(method, params = {}, user: nil)
    headers = { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
    headers["Authorization"] = "Bearer #{user.token}" if user

    post("/mcp", params: { jsonrpc: "2.0", id: 1, method:, params: }.to_json, headers:)
    JSON.parse(response.body)
  end

  def call_tool(name, arguments = {}, user:)
    body = mcp("tools/call", { name:, arguments: }, user:)
    assert_nil body["error"], body["error"].inspect

    body["result"]
  end

  def list_tools(user:)
    mcp("tools/list", user:).dig("result", "tools").index_by { |tool| tool["name"] }
  end

  # Runs the block in a transaction that is rolled back, so the next run starts from the same data
  def rolled_back
    result = nil

    ActiveRecord::Base.transaction(requires_new: true) do
      result = yield
      raise ActiveRecord::Rollback
    end

    result
  end
end
