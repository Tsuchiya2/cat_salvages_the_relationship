# ⚠️ WARNING: DO NOT RUN THIS MIGRATION YET ⚠️
#
# This migration removes Sorcery-specific columns from the operators table.
#
# IMPORTANT: Only run this migration AFTER completing the 30-day production verification period
# and confirming that:
#   1. All operators can successfully authenticate using password_digest (has_secure_password)
#   2. No authentication failures have been reported
#   3. The legacy Sorcery authentication code is no longer in use
#
# If you need to rollback after running this migration, the down method will restore the columns,
# but you will need to re-migrate password hashes from password_digest back to crypted_password.

class RemoveSorceryColumnsFromOperators < ActiveRecord::Migration[8.1]
  def up
    # ⚠️ WARNING: Only run after 30-day production verification period ⚠️
    # Ensure all operators can authenticate with password_digest before proceeding

    remove_column :operators, :crypted_password, :string
    remove_column :operators, :salt, :string
  end

  def down
    # Rollback: Restore Sorcery columns
    # Note: You will need to re-migrate password hashes if rolling back

    add_column :operators, :crypted_password, :string
    add_column :operators, :salt, :string
  end
end
