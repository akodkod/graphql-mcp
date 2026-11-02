# frozen_string_literal: true

module Mutations
  class DeletePost < BaseMutation
    description "Delete a post owned by the current user"

    argument :id, ID, required: true

    field :deleted_id, ID, null: false

    def resolve(id:)
      post = Post.find(id)
      authorize_author!(post)
      post.destroy!

      { deleted_id: post.id }
    end
  end
end
