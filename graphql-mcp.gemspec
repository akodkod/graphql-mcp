# frozen_string_literal: true

require_relative "lib/graphql/mcp/version"

Gem::Specification.new do |spec|
  spec.name = "graphql-mcp"
  spec.version = GraphQLMCP::VERSION
  spec.authors = ["Andrew Kodkod"]
  spec.email = ["678665+akodkod@users.noreply.github.com"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/akodkod/graphql-mcp"
  spec.summary = "Expose a GraphQL-Ruby schema as an MCP server."
  spec.description = "Generates MCP tools with input and output schemas from GraphQL queries, mutations and types, and executes every call through the original schema."
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb", "rbi/**/*.rbi", "README.md", "LICENSE.txt", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "graphql", ">= 2.4", "< 3"
  spec.add_dependency "mcp", "~> 1.8"
  spec.add_dependency "rack", ">= 2.2", "< 4"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
end
