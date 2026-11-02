# frozen_string_literal: true

# Serves the dummy app for manual checks with real MCP clients:
#   bundle exec puma test/dummy/config.ru -p 9292

ENV["RAILS_ENV"] ||= "test"
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "fileutils"
require_relative "config/environment"

# Request threads cannot see the tests' in-memory database, so the server uses a fresh file
database = File.expand_path("../../tmp/dummy.sqlite3", __dir__)
FileUtils.mkdir_p(File.dirname(database))
FileUtils.rm_f(database)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database:)

ActiveRecord::Migration.verbose = false
load File.expand_path("db/schema.rb", __dir__)

ada = User.create!(name: "Ada", email: "ada@example.com", token: "dev-token")
Post.create!(author: ada, title: "Hello MCP", body: "first post from the dummy app", status: :published, rating: 4.5)

run Rails.application
