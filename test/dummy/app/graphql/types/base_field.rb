# frozen_string_literal: true

module Types
  # Mirrors fields that exist in code but are hidden from this schema, like 811spotter's internal fields
  class BaseField < GraphQL::Schema::Field
    def initialize(*, hidden: false, **, &)
      @hidden = hidden
      super(*, **, &)
    end

    def visible?(context)
      super && !@hidden
    end
  end
end
