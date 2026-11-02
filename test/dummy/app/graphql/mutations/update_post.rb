# frozen_string_literal: true

module Mutations
  class UpdatePost < BaseMutation
    description "Update a post owned by the current user"

    argument :id, ID, required: true
    argument :input, Types::PostInput, required: true

    field :post, Types::PostType
    field :errors, [String], null: false

    def resolve(id:, input:)
      post = Post.find(id)
      authorize_author!(post)

      if post.update(**input.to_h)
        { post:, errors: [] }
      else
        { post: nil, errors: post.errors.full_messages }
      end
    end
  end
end
