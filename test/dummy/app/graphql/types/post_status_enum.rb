# frozen_string_literal: true

module Types
  class PostStatusEnum < BaseEnum
    description "Publication status of a post"

    value "DRAFT", "Visible only to its author", value: "draft"
    value "PUBLISHED", "Visible to everyone", value: "published"
    value "ARCHIVED", "Hidden from lists", value: "archived"
  end
end
