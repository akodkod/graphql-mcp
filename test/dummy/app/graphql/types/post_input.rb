# frozen_string_literal: true

module Types
  class PostInput < BaseInputObject
    description "Attributes for creating or updating a post"

    argument :title, String, required: true
    argument :body, String, required: false
    argument :status, Types::PostStatusEnum, required: false, default_value: "draft"
    argument :rating, Float, required: false
    argument :featured, Boolean, required: false
    argument :scheduled_on, GraphQL::Types::ISO8601Date, required: false
    argument :tags, [String], required: false
    argument :metadata, GraphQL::Types::JSON, required: false
  end
end
