class SorceryCore < ActiveRecord::Migration[6.1]
  def change
    create_table :operators do |t|
      t.string :name,               null: false
      t.string :email,              null: false
      t.string :crypted_password
      t.string :salt
      t.integer :role,              default: 1, null: false
      t.timestamps
    end

    add_index :operators, :email, unique: true
  end
end
