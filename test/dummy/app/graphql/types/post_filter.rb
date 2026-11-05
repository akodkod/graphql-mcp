# frozen_string_literal: true

module Types
  # Refers to itself through `not`, like recursive filter inputs in other schemas
  class PostFilter < BaseInputObject
    description "Conditions on posts"

    argument :title_contains, String, required: false
    argument :id_in, [ID], required: false
    argument :statuses, [Types::PostStatusEnum], required: false
    argument :not, Types::PostFilter, required: false

    def apply(scope)
      scope = scope.where("title LIKE ?", "%#{Post.sanitize_sql_like(title_contains)}%") if title_contains
      scope = scope.where(id: id_in) if id_in
      scope = scope.where(status: statuses) if statuses
      scope = scope.where.not(id: self.not.apply(Post.all).select(:id)) if self.not
      scope
    end
  end
end
