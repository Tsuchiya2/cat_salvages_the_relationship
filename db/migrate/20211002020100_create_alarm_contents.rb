class CreateAlarmContents < ActiveRecord::Migration[6.1]
  def change
    create_table :alarm_contents do |t|
      t.string :body,         null: false
      t.integer :category,  null: false, default: 0
      t.timestamps
    end

    add_index :alarm_contents, :body, unique: true
  end
end
