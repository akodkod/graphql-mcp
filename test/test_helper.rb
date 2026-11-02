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
end
