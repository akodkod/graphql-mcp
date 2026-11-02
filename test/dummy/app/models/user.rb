# frozen_string_literal: true

class User < ApplicationRecord
  has_many :posts, foreign_key: :author_id, inverse_of: :author, dependent: :destroy

  validates :name, :email, :token, presence: true
end
