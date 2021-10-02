class CreateOperators < ActiveRecord::Migration[6.1]
  def change
    create_table :operators do |t|
      t.string :name,               null: false
      t.string :email,              null: false
      t.string :crypted_password
      t.string :salt
      t.integer :role,              null: false, default: 1
      t.timestamps
    end

    add_index :operators, :email, unique: true
  end
end
