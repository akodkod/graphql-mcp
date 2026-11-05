# frozen_string_literal: true

module Types
  class QueryType < BaseObject
    field :post, Types::PostType, description: "Find a post by ID" do
      argument :id, ID, required: true
    end

    field :posts, Types::PostType.connection_type, null: false, description: "List posts, newest first" do
      argument :status, Types::PostStatusEnum, required: false
      argument :author_id, ID, required: false
      argument :filter, Types::PostFilter, required: false
    end

    field :node, Types::NodeInterface, description: "Find a post or user by a global ID like Post:1" do
      argument :id, ID, required: true
    end

    field :search, [Types::SearchResultUnion], null: false, description: "Find posts by title and users by name" do
      argument :query, String, required: true
    end

    field :viewer, Types::UserType, description: "The authenticated user"

    def post(id:)
      Post.find(id)
    end

    def posts(status: nil, author_id: nil, filter: nil)
      scope = Post.order(created_at: :desc, id: :desc)
      scope = scope.where(status:) if status
      scope = scope.where(author_id:) if author_id
      scope = filter.apply(scope) if filter
      scope
    end

    def node(id:)
      model, record_id = id.split(":", 2)
      raise GraphQL::ExecutionError, "Invalid ID: #{id}" unless ["Post", "User"].include?(model)

      model.constantize.find(record_id)
    end

    def search(query:)
      pattern = "%#{Post.sanitize_sql_like(query)}%"
      Post.where("title LIKE ?", pattern).order(:id).to_a + User.where("name LIKE ?", pattern).order(:id).to_a
    end

    def viewer
      context[:current_user]
    end
  end
end
