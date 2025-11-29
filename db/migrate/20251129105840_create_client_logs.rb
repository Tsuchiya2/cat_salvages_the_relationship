# frozen_string_literal: true

class CreateClientLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :client_logs do |t|
      t.string :level, null: false
      t.text :message, null: false
      t.json :context
      t.text :user_agent
      t.text :url
      t.string :trace_id

      t.timestamp :created_at, null: false
    end

    add_index :client_logs, :trace_id
    add_index :client_logs, :level
    add_index :client_logs, :created_at
    add_index :client_logs, [:level, :created_at]
  end
end
