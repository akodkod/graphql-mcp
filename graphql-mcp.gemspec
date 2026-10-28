# frozen_string_literal: true

require_relative "lib/graphql/mcp/version"

Gem::Specification.new do |spec|
  spec.name = "graphql-mcp"
  spec.version = Graphql::Mcp::VERSION
  spec.authors = ["Andrew Kodkod"]
  spec.email = ["678665+akodkod@users.noreply.github.com"]

  spec.summary = "Build an MCP server from GraphQL schemas"
  spec.description = "Build an MCP server from GraphQL schemas, providing tools and utilities to easily construct and manage a modular, composable GraphQL server architecture."
  spec.homepage = "https://github.com/akodkod/graphql-mcp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/akodkod/graphql-mcp"
  spec.metadata["changelog_uri"] = "https://github.com/akodkod/graphql-mcp/blob/main/CHANGELOG.md"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.end_with?(".gem") ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
