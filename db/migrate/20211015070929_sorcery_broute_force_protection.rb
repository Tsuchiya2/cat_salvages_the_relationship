class SorceryBrouteForceProtection < ActiveRecord::Migration[6.1]
  def change
    add_column :operators, :failed_logins_count, :integer, default: 0
    add_column :operators, :lock_expires_at, :datetime, default: nil
    add_column :operators, :unlock_token, :string, default: nil

    add_index :operators, :unlock_token
  end
end
