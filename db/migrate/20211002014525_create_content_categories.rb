class CreateContentCategories < ActiveRecord::Migration[6.1]
  def change
    create_table :content_categories do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
