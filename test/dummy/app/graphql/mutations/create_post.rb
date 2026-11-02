# frozen_string_literal: true

module Mutations
  class CreatePost < BaseMutation
    description "Create a post authored by the current user"

    argument :input, Types::PostInput, required: true

    field :post, Types::PostType
    field :errors, [String], null: false

    def resolve(input:)
      post = current_user.posts.build(**input.to_h)
      post.published_at = Time.current if post.published?

      if post.save
        { post:, errors: [] }
      else
        { post: nil, errors: post.errors.full_messages }
      end
    end
  end
end
