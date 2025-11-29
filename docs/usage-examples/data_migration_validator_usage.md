# DataMigrationValidator Usage Guide

## Overview

`DataMigrationValidator` is a utility class for validating data migrations with checksums and integrity checks. It helps ensure data integrity during schema changes or data transformations.

## Purpose

This validator is particularly useful for:
- Validating password migration from Sorcery (crypted_password) to BCrypt (password_digest)
- Ensuring no data loss during migrations
- Verifying data integrity after transformations
- Generating checksums for tracking data changes

## API Reference

### Methods

#### `generate_checksum(model_class)`

Generates SHA256 checksums for records to track data integrity.

**Parameters:**
- `model_class` (Class): ActiveRecord model class to generate checksums for

**Returns:**
- Array<String>: Array of SHA256 checksums, one per record

**Example:**
```ruby
# Generate checksums before migration
before_checksums = DataMigrationValidator.generate_checksum(Operator)
# => ["a1b2c3d4e5...", "f6g7h8i9j0...", ...]
```

---

#### `validate_migration(before_checksums, after_checksums)`

Validates migration by comparing before and after checksums.

**Parameters:**
- `before_checksums` (Array<String>): Checksums before migration
- `after_checksums` (Array<String>): Checksums after migration

**Returns:**
- Boolean: true if migration is valid

**Raises:**
- RuntimeError: if checksums don't match

**Example:**
```ruby
before = DataMigrationValidator.generate_checksum(Operator)

# Perform migration here
migrate_passwords

after = DataMigrationValidator.generate_checksum(Operator)
DataMigrationValidator.validate_migration(before, after)
# => true (or raises error if validation fails)
```

---

#### `verify_integrity(model_class)`

Verifies data integrity for a specific model.

**Parameters:**
- `model_class` (Class): ActiveRecord model class to verify

**Returns:**
- Hash: Hash with integrity check results
  - `valid` (Boolean): true if no issues found
  - `total_records` (Integer): Total number of records
  - `issues` (Array<String>): List of integrity issues

**Example:**
```ruby
result = DataMigrationValidator.verify_integrity(Operator)
# => {
#   valid: false,
#   total_records: 100,
#   issues: [
#     "5 records missing authentication data",
#     "2 records have both crypted_password and password_digest"
#   ]
# }
```

---

#### `validate_password_migration`

Validates password migration from Sorcery to BCrypt.

**Returns:**
- Boolean: true if migration is complete

**Raises:**
- RuntimeError: if migration is incomplete

**Example:**
```ruby
DataMigrationValidator.validate_password_migration
# => true (or raises "Migration incomplete: X operators missing password_digest")
```

## Usage Examples

### Example 1: Validating Password Migration in a Migration Script

```ruby
class MigrateOperatorPasswords < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Generate checksums before migration
    before_checksums = DataMigrationValidator.generate_checksum(Operator)
    puts "Generated checksums for #{before_checksums.size} operators"

    # Step 2: Perform migration
    Operator.find_each do |operator|
      next if operator.crypted_password.blank?

      # Copy Sorcery password to BCrypt format
      operator.update_columns(
        password_digest: operator.crypted_password
      )
    end

    # Step 3: Validate migration
    after_checksums = DataMigrationValidator.generate_checksum(Operator)
    DataMigrationValidator.validate_migration(before_checksums, after_checksums)
    puts "Migration validated successfully"

    # Step 4: Verify password migration specifically
    DataMigrationValidator.validate_password_migration
    puts "Password migration complete"
  end

  def down
    # Rollback: restore crypted_password
    Operator.update_all(password_digest: nil)
  end
end
```

### Example 2: Pre-Migration Integrity Check

```ruby
# Before running migration, check current state
result = DataMigrationValidator.verify_integrity(Operator)

if result[:valid]
  puts "All #{result[:total_records]} operators have valid authentication data"
  puts "Safe to proceed with migration"
else
  puts "WARNING: Data integrity issues found:"
  result[:issues].each { |issue| puts "  - #{issue}" }
  puts "Please fix these issues before migrating"
end
```

### Example 3: Post-Migration Validation

```ruby
# After migration, validate results
begin
  DataMigrationValidator.validate_password_migration
  puts "✅ Password migration completed successfully"
rescue RuntimeError => e
  puts "❌ Migration failed: #{e.message}"
  # Trigger rollback or alert
end
```

### Example 4: Monitoring Data Changes

```ruby
# Take snapshot before risky operation
snapshot = DataMigrationValidator.generate_checksum(Operator)

# Perform risky operation
perform_bulk_update

# Verify no unexpected changes
current = DataMigrationValidator.generate_checksum(Operator)
begin
  DataMigrationValidator.validate_migration(snapshot, current)
  puts "Data integrity verified"
rescue RuntimeError => e
  puts "Unexpected data changes: #{e.message}"
  # Rollback or investigate
end
```

## Error Messages

### Migration Validation Errors

**Records Lost:**
```
Migration validation failed: 5 records lost
```
- Meaning: 5 records were deleted during migration
- Action: Investigate why records were lost, restore from backup

**Unexpected Records Added:**
```
Migration validation failed: 3 unexpected records added
```
- Meaning: 3 new records were created during migration
- Action: Verify if this was intentional

**Records Modified:**
```
Migration validation failed: 10 records modified or corrupted
```
- Meaning: Data in 10 records changed unexpectedly
- Action: Check migration logic for unintended side effects

### Password Migration Errors

```
Migration incomplete: 25 operators missing password_digest
```
- Meaning: 25 operators still have crypted_password but no password_digest
- Action: Complete migration for remaining operators

## Best Practices

### 1. Always Generate Checksums Before Migration

```ruby
# Good: Capture state before making changes
before = DataMigrationValidator.generate_checksum(Operator)
migrate_data
after = DataMigrationValidator.generate_checksum(Operator)
DataMigrationValidator.validate_migration(before, after)
```

### 2. Run Integrity Checks in Development First

```ruby
# In development environment
result = DataMigrationValidator.verify_integrity(Operator)
abort("Fix integrity issues first") unless result[:valid]
```

### 3. Use Transactions for Rollback Safety

```ruby
ActiveRecord::Base.transaction do
  before = DataMigrationValidator.generate_checksum(Operator)

  migrate_passwords

  after = DataMigrationValidator.generate_checksum(Operator)
  DataMigrationValidator.validate_migration(before, after)
  DataMigrationValidator.validate_password_migration
rescue RuntimeError => e
  # Transaction will rollback automatically
  raise e
end
```

### 4. Log Validation Results

```ruby
before = DataMigrationValidator.generate_checksum(Operator)
Rails.logger.info "Migration started: #{before.size} operators"

migrate_passwords

after = DataMigrationValidator.generate_checksum(Operator)
DataMigrationValidator.validate_migration(before, after)
Rails.logger.info "Migration validated: #{after.size} operators"
```

## Testing

Run the test suite:

```bash
bundle exec rspec spec/services/data_migration_validator_spec.rb
```

Expected output:
```
DataMigrationValidator
  .generate_checksum
    generates checksums for all records
    generates SHA256 checksums
    generates consistent checksums for same data
    generates different checksums when data changes
  .validate_migration
    when checksums match
      returns true
    when records are lost
      raises error with missing count
    when unexpected records are added
      raises error with added count
    when records are modified
      raises error about modified records
    when order changes but data is same
      returns true
  .verify_integrity
    when all records have valid authentication data
      returns valid result
    when records have missing authentication data
      reports missing authentication data
    when records have duplicate authentication methods
      reports duplicate authentication methods
  .validate_password_migration
    when all operators have password_digest
      returns true
    when operators are missing password_digest
      raises error with missing count
    when operators only have password_digest
      returns true

15 examples, 0 failures
```

## Related Documentation

- [Password Migration Task](../plans/password-migration-tasks.md)
- [Operator Model](../../app/models/operator.rb)
- [Migration Guide](../migration-guide.md)
