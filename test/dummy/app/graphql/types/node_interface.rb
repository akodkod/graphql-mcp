# frozen_string_literal: true

module Types
  module NodeInterface
    include GraphQL::Schema::Interface

    graphql_name "Node"
    description "A record with a global ID"

    field :id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
