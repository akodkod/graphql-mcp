# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name, null: false
    t.string :email, null: false
    t.string :token, null: false, index: { unique: true }
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.references :author, null: false, foreign_key: { to_table: :users }
    t.string :title, null: false
    t.text :body
    t.integer :status, null: false, default: 0
    t.float :rating
    t.boolean :featured, null: false, default: false
    t.datetime :published_at
    t.timestamps
  end
end
