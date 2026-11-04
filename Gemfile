# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "irb"
gem "rake", ">= 13", "< 14"

group :test do
  gem "actionpack", ENV.fetch("RAILS_VERSION", "~> 8.1")
  gem "activerecord", ENV.fetch("RAILS_VERSION", "~> 8.1")
  gem "minitest", ">= 5", "< 7"
  gem "railties", ENV.fetch("RAILS_VERSION", "~> 8.1")
  gem "sqlite3", ">= 2.1"
end

group :development do
  gem "faraday", require: false
  gem "puma", require: false
  gem "rubocop", "1.92.1", require: false
  gem "rubocop-performance", "1.27.0", require: false
  gem "rubocop-sane", github: "akodkod/rubocop-sane", ref: "ff2d8ffbeb4785d928aacadb3a3ec8d6175ef361", require: false
  gem "sorbet-static", require: false
end
