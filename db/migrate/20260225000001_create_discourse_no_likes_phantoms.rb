# frozen_string_literal: true

class CreateDiscourseNoLikesPhantoms < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_no_likes_phantoms do |t|
      t.integer :post_id,       null: false
      t.integer :user_id,       null: false
      t.integer :category_id,   null: false
      t.string  :reaction_type, null: false, default: "like"
      t.timestamps
    end

    add_index :discourse_no_likes_phantoms, %i[post_id user_id]
    add_index :discourse_no_likes_phantoms, :user_id
    add_index :discourse_no_likes_phantoms, :category_id
  end
end
