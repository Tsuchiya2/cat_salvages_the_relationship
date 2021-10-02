class CreateContents < ActiveRecord::Migration[6.1]
  def change
    create_table :contents do |t|
      t.text :body,                     null: false
      t.references :content_category,   foreign_key: true
      t.timestamps
    end
  end
end
