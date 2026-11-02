# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::Mutation
    def ready?(**_arguments)
      return true if current_user

      raise GraphQL::ExecutionError, "Authentication required"
    end

    private

    def current_user
      context[:current_user]
    end

    def authorize_author!(post)
      return if post.author_id == current_user.id

      raise GraphQL::ExecutionError, "Not authorized to change this post"
    end
  end
end
