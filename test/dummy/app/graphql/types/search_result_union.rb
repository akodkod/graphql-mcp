# frozen_string_literal: true

module Types
  class SearchResultUnion < GraphQL::Schema::Union
    graphql_name "SearchResult"
    description "A post or a user"

    possible_types Types::PostType, Types::UserType
  end
end
