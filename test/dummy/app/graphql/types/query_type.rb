# frozen_string_literal: true

module Types
  class QueryType < BaseObject
    field :post, Types::PostType, description: "Find a post by ID" do
      argument :id, ID, required: true
    end

    field :posts, Types::PostType.connection_type, null: false, description: "List posts, newest first" do
      argument :status, Types::PostStatusEnum, required: false
      argument :author_id, ID, required: false
    end

    field :viewer, Types::UserType, description: "The authenticated user"

    def post(id:)
      Post.find(id)
    end

    def posts(status: nil, author_id: nil)
      scope = Post.order(created_at: :desc, id: :desc)
      scope = scope.where(status:) if status
      scope = scope.where(author_id:) if author_id
      scope
    end

    def viewer
      context[:current_user]
    end
  end
end
