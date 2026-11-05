# frozen_string_literal: true

module Types
  class PostType < BaseObject
    graphql_name "Post"
    description "A blog post"
    implements Types::NodeInterface

    field :id, ID, null: false
    field :title, String, null: false
    field :body, String
    field :status, Types::PostStatusEnum, null: false
    field :rating, Float
    field :featured, Boolean, null: false
    field :word_count, Int, null: false
    field :published_at, GraphQL::Types::ISO8601DateTime
    field :scheduled_on, GraphQL::Types::ISO8601Date
    field :tags, [String], null: false
    field :metadata, GraphQL::Types::JSON
    field :author, Types::UserType, null: false
    field :moderation_note, String, hidden: true
  end
end
