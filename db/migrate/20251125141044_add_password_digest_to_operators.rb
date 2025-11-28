class AddPasswordDigestToOperators < ActiveRecord::Migration[8.1]
  def change
    add_column :operators, :password_digest, :string
    add_index :operators, :password_digest
  end
end
