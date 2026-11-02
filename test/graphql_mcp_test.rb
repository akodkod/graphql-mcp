# frozen_string_literal: true

require "test_helper"

class GraphQLMCPTest < Minitest::Test
  def test_version
    assert_match(/\A\d+\.\d+\.\d+/, GraphQLMCP::VERSION)
  end

  def test_gem_ships_sorbet_signatures
    spec = Gem::Specification.load(File.expand_path("../graphql-mcp.gemspec", __dir__))

    assert_includes spec.files, "rbi/graphql_mcp.rbi"
    assert_includes spec.files, "lib/graphql/mcp.rb"
    refute(spec.files.any? { |file| file.start_with?("test/") })
  end
end
