class CreateAlarmContents < ActiveRecord::Migration[6.1]
  def change
    create_table :alarm_contents do |t|
      t.text :body,                           null: false
      t.references :alarm_content_category,   foreign_key: true
      t.timestamps
    end
  end
end
