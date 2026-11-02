# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new do |test|
  test.libs << "test"
  test.pattern = "test/**/*_test.rb"
end

RuboCop::RakeTask.new

# Calls the binary directly: `srb tc` also loads RBIs shipped by other gems, which may not type-check
desc "Type-check the shipped RBI signatures with Sorbet"
task :sorbet do
  sh File.join(Gem.loaded_specs.fetch("sorbet-static").full_gem_path, "libexec", "sorbet")
end

task default: [:test, :rubocop, :sorbet]
