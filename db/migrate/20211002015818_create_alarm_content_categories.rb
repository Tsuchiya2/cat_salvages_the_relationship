class CreateAlarmContentCategories < ActiveRecord::Migration[6.1]
  def change
    create_table :alarm_content_categories do |t|
      t.string :name, null:false
      t.timestamps
    end
  end
end
