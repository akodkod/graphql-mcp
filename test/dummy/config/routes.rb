# frozen_string_literal: true

mcp = GraphQLMCP::Spike::RackApp.new(
  name: "dummy",
  tools: SpikeTools.all,
  context: -> (request) {
    token = request.get_header("HTTP_AUTHORIZATION").to_s.delete_prefix("Bearer ").presence
    user = token && User.find_by(token:)
    user && { current_user: user }
  },

  # The SDK rejects any Host but loopback by default (DNS rebinding protection)
  allowed_hosts: ["www.example.com"],
)

Rails.application.routes.draw do
  post "graphql", to: "graphql#execute"
  mount mcp, at: "mcp"
end
