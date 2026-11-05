# frozen_string_literal: true

module Types
  class UserType < BaseObject
    graphql_name "User"
    description "A post author"
    implements Types::NodeInterface

    field :id, ID, null: false
    field :name, String, null: false
    field :posts, [Types::PostType], null: false
  end
end
