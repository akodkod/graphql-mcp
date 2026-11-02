# frozen_string_literal: true

module Types
  class PostType < BaseObject
    graphql_name "Post"
    description "A blog post"

    field :id, ID, null: false
    field :title, String, null: false
    field :body, String
    field :status, Types::PostStatusEnum, null: false
    field :rating, Float
    field :featured, Boolean, null: false
    field :word_count, Int, null: false
    field :published_at, GraphQL::Types::ISO8601DateTime
    field :author, Types::UserType, null: false
  end
end
