# frozen_string_literal: true

require "logger"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "graphql"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults Rails::VERSION::STRING.to_f
    config.api_only = true
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.secret_key_base = "dummy-secret-key-base"
    config.hosts.clear

    # The test helper loads db/schema.rb into the in-memory database itself
    config.active_record.maintain_test_schema = false
  end
end
