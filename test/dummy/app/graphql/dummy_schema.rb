# frozen_string_literal: true

class DummySchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  max_depth 10
  default_max_page_size 50

  rescue_from ActiveRecord::RecordNotFound do |error|
    raise GraphQL::ExecutionError, "#{error.model} not found"
  end
end
