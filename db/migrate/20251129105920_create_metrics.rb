# frozen_string_literal: true

class CreateMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :metrics do |t|
      t.string :name, null: false
      t.decimal :value, precision: 15, scale: 4, null: false
      t.string :unit
      t.json :tags
      t.string :trace_id

      t.timestamp :created_at, null: false
    end

    add_index :metrics, :name
    add_index :metrics, :trace_id
    add_index :metrics, :created_at
    add_index :metrics, [:name, :created_at]
  end
end
