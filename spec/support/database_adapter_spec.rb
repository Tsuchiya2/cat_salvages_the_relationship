# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Database Adapter Configuration', type: :support do
  describe 'Adapter Type' do
    it 'uses mysql2 adapter in all environments' do
      expect(ActiveRecord::Base.connection.adapter_name).to eq('Mysql2')
    end

    it 'returns correct adapter name through connection' do
      adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
      expect(adapter_name).to eq('mysql2')
    end
  end

  describe 'Character Encoding' do
    it 'uses utf8mb4 encoding for database' do
      encoding = ActiveRecord::Base.connection.execute(
        "SHOW VARIABLES LIKE 'character_set_database'"
      ).first
      expect(encoding[1]).to eq('utf8mb4')
    end

    it 'uses utf8mb4 for connection character set' do
      encoding = ActiveRecord::Base.connection.execute(
        "SHOW VARIABLES LIKE 'character_set_connection'"
      ).first
      expect(encoding[1]).to eq('utf8mb4')
    end

    it 'uses utf8mb4 for results character set' do
      encoding = ActiveRecord::Base.connection.execute(
        "SHOW VARIABLES LIKE 'character_set_results'"
      ).first
      expect(encoding[1]).to eq('utf8mb4')
    end
  end

  describe 'Collation' do
    it 'uses utf8mb4_unicode_ci collation for database' do
      collation = ActiveRecord::Base.connection.execute(
        "SHOW VARIABLES LIKE 'collation_database'"
      ).first
      expect(collation[1]).to eq('utf8mb4_unicode_ci')
    end

    it 'uses utf8mb4_unicode_ci for connection collation' do
      collation = ActiveRecord::Base.connection.execute(
        "SHOW VARIABLES LIKE 'collation_connection'"
      ).first
      expect(collation[1]).to eq('utf8mb4_unicode_ci')
    end
  end

  describe 'MySQL Version' do
    it 'runs MySQL 8.0 or higher' do
      version_string = ActiveRecord::Base.connection.select_value('SELECT VERSION()')
      version = version_string.split('-').first.split('.').first.to_i

      expect(version).to be >= 8
    end

    it 'provides version information' do
      version = ActiveRecord::Base.connection.select_value('SELECT VERSION()')
      expect(version).to be_present
      expect(version).to match(/^\d+\.\d+\.\d+/)
    end
  end

  describe 'Connection Pool' do
    it 'has a configured connection pool' do
      pool = ActiveRecord::Base.connection_pool
      expect(pool).to be_present
      expect(pool.size).to be > 0
    end

    it 'can establish multiple connections' do
      pool = ActiveRecord::Base.connection_pool
      expect(pool.size).to be >= 5
    end
  end

  describe 'Database Configuration' do
    it 'has correct database configuration' do
      config = ActiveRecord::Base.connection_db_config.configuration_hash

      expect(config[:adapter]).to eq('mysql2')
      expect(config[:encoding]).to eq('utf8mb4')
      expect(config[:collation]).to eq('utf8mb4_unicode_ci')
    end

    it 'has reconnect enabled' do
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      expect(config[:reconnect]).to be true
    end

    it 'has appropriate timeout configured' do
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      expect(config[:timeout]).to be_present
      expect(config[:timeout]).to be >= 5000
    end
  end

  describe 'SQL Mode' do
    it 'has appropriate SQL mode set' do
      sql_mode = ActiveRecord::Base.connection.execute(
        "SHOW VARIABLES LIKE 'sql_mode'"
      ).first[1]

      # MySQL 8 default includes STRICT modes
      expect(sql_mode).to include('STRICT')
    end
  end

  describe 'Time Zone' do
    it 'has a configured time zone' do
      time_zone = ActiveRecord::Base.connection.execute(
        "SHOW VARIABLES LIKE 'time_zone'"
      ).first[1]

      expect(time_zone).to be_present
    end
  end
end
