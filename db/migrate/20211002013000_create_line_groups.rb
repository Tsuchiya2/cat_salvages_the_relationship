class CreateLineGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :line_groups do |t|
      t.string :line_group_id,  null: false
      t.date :remind_at,        null: false
      t.integer :status,        null: false, default: 0
      t.timestamps
    end

    add_index :line_groups, :line_group_id, unique: true
  end
end
