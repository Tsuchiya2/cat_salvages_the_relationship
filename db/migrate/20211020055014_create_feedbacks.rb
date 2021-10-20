class CreateFeedbacks < ActiveRecord::Migration[6.1]
  def change
    create_table :feedbacks do |t|
      t.text :text,   null: false
      t.timestamps
    end
  end
end
