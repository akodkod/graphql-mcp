# frozen_string_literal: true

class Post < ApplicationRecord
  belongs_to :author, class_name: "User", inverse_of: :posts

  enum :status, { draft: 0, published: 1, archived: 2 }

  validates :title, presence: true, length: { maximum: 100 }
  validates :rating, numericality: { in: 0..5 }, allow_nil: true

  def word_count
    body.to_s.split.size
  end
end
