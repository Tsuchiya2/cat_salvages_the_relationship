# frozen_string_literal: true

module DatabaseMigration
  module Services
    # Connection manager for establishing database connections
    # Supports multiple database adapters
    class ConnectionManager
      # Establishes a database connection
      # @param adapter [String, Symbol] adapter type ('mysql2', 'postgresql')
      # @param config [Hash] connection configuration
      # @return [Object] database connection object
      def self.establish_connection(adapter:, config:)
        case adapter.to_s.downcase
        when 'mysql2', 'mysql8'
          establish_mysql_connection(config)
        when 'postgresql', 'pg'
          establish_postgresql_connection(config)
        else
          raise ArgumentError, "Unsupported adapter: #{adapter}"
        end
      end

      # Tests database connection
      # @param adapter [String, Symbol] adapter type
      # @param config [Hash] connection configuration
      # @return [Hash] test result
      def self.test_connection(adapter:, config:)
        connection = establish_connection(adapter: adapter, config: config)

        result = case adapter.to_s.downcase
                 when 'mysql2', 'mysql8'
                   test_mysql_connection(connection)
                 when 'postgresql', 'pg'
                   test_postgresql_connection(connection)
                 else
                   { success: false, error: "Unknown adapter: #{adapter}" }
                 end

        connection.close if connection.respond_to?(:close)

        result
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          adapter: adapter.to_s
        }
      end

      # Gets connection parameters for adapter
      # @param adapter [String, Symbol] adapter type
      # @param config [Hash] base configuration
      # @return [Hash] connection parameters
      def self.connection_params(adapter:, config: {})
        case adapter.to_s.downcase
        when 'mysql2', 'mysql8'
          mysql_connection_params(config)
        when 'postgresql', 'pg'
          postgresql_connection_params(config)
        else
          raise ArgumentError, "Unsupported adapter: #{adapter}"
        end
      end

      class << self
        private

        # Establishes MySQL connection
        # @param config [Hash] connection configuration
        # @return [Mysql2::Client] MySQL connection
        def establish_mysql_connection(config)
          require 'mysql2'

          params = mysql_connection_params(config)
          Mysql2::Client.new(params)
        rescue LoadError
          raise 'mysql2 gem not available. Please add it to your Gemfile.'
        end

        # Establishes PostgreSQL connection
        # @param config [Hash] connection configuration
        # @return [PG::Connection] PostgreSQL connection
        def establish_postgresql_connection(config)
          require 'pg'

          params = postgresql_connection_params(config)
          PG.connect(params)
        rescue LoadError
          raise 'pg gem not available. Please add it to your Gemfile.'
        end

        # Builds MySQL connection parameters
        # @param config [Hash] base configuration
        # @return [Hash] MySQL connection parameters
        def mysql_connection_params(config)
          {
            host: fetch_param(config, :host, 'DB_HOST', 'localhost'),
            port: fetch_param(config, :port, 'DB_PORT', 3306).to_i,
            username: fetch_param(config, :username, 'DB_USERNAME', 'root'),
            password: fetch_param(config, :password, 'DB_PASSWORD'),
            database: fetch_param(config, :database, 'DB_NAME', 'reline_production'),
            encoding: 'utf8mb4',
            reconnect: true
          }
        end

        # Builds PostgreSQL connection parameters
        # @param config [Hash] base configuration
        # @return [Hash] PostgreSQL connection parameters
        def postgresql_connection_params(config)
          {
            host: fetch_param(config, :host, 'PG_HOST', 'localhost'),
            port: fetch_param(config, :port, 'PG_PORT', 5432).to_i,
            user: fetch_param(config, :username, 'PG_USER', 'postgres'),
            password: fetch_param(config, :password, 'PG_PASSWORD'),
            dbname: fetch_param(config, :database, 'PG_DATABASE', 'reline_production')
          }
        end

        # Fetches parameter from config, ENV, or default value
        # @param config [Hash] configuration hash
        # @param key [Symbol] parameter key
        # @param env_key [String] environment variable name
        # @param default [Object] default value
        # @return [Object] parameter value
        def fetch_param(config, key, env_key, default = nil)
          config[key] || ENV[env_key] || default
        end

        # Tests MySQL connection
        # @param connection [Mysql2::Client] MySQL connection
        # @return [Hash] test result
        def test_mysql_connection(connection)
          result = connection.query('SELECT 1 AS test').first

          {
            success: result['test'] == 1,
            adapter: 'mysql2',
            version: connection.server_info[:version]
          }
        end

        # Tests PostgreSQL connection
        # @param connection [PG::Connection] PostgreSQL connection
        # @return [Hash] test result
        def test_postgresql_connection(connection)
          result = connection.exec('SELECT 1 AS test').first

          {
            success: result['test'] == '1',
            adapter: 'postgresql',
            version: connection.server_version
          }
        end
      end
    end
  end
end
