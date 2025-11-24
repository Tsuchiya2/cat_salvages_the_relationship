# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../lib/database_migration/services/connection_manager'

RSpec.describe DatabaseMigration::Services::ConnectionManager do
  describe '.establish_connection' do
    context 'for MySQL' do
      let(:config) do
        {
          host: 'localhost',
          port: 3306,
          username: 'root',
          password: 'password',
          database: 'test_db'
        }
      end

      it 'establishes MySQL connection with mysql2 adapter' do
        mock_client = instance_double('Mysql2::Client')
        allow(described_class).to receive(:require).with('mysql2')
        allow(Mysql2::Client).to receive(:new).and_return(mock_client)

        connection = described_class.establish_connection(adapter: 'mysql2', config: config)

        expect(connection).to eq(mock_client)
      end

      it 'establishes MySQL connection with mysql8 adapter' do
        mock_client = instance_double('Mysql2::Client')
        allow(described_class).to receive(:require).with('mysql2')
        allow(Mysql2::Client).to receive(:new).and_return(mock_client)

        connection = described_class.establish_connection(adapter: 'mysql8', config: config)

        expect(connection).to eq(mock_client)
      end

      it 'raises error if mysql2 gem is not available' do
        allow(described_class).to receive(:require).with('mysql2').and_raise(LoadError)

        expect {
          described_class.establish_connection(adapter: 'mysql2', config: config)
        }.to raise_error('mysql2 gem not available. Please add it to your Gemfile.')
      end
    end

    context 'for PostgreSQL' do
      let(:config) do
        {
          host: 'localhost',
          port: 5432,
          username: 'postgres',
          password: 'password',
          database: 'test_db'
        }
      end

      it 'establishes PostgreSQL connection with postgresql adapter' do
        mock_connection = instance_double('PG::Connection')
        mock_pg = double('PG')
        stub_const('PG', mock_pg)

        allow(described_class).to receive(:require).with('pg')
        allow(mock_pg).to receive(:connect).and_return(mock_connection)

        connection = described_class.establish_connection(adapter: 'postgresql', config: config)

        expect(connection).to eq(mock_connection)
      end

      it 'establishes PostgreSQL connection with pg adapter' do
        mock_connection = instance_double('PG::Connection')
        mock_pg = double('PG')
        stub_const('PG', mock_pg)

        allow(described_class).to receive(:require).with('pg')
        allow(mock_pg).to receive(:connect).and_return(mock_connection)

        connection = described_class.establish_connection(adapter: 'pg', config: config)

        expect(connection).to eq(mock_connection)
      end

      it 'raises error if pg gem is not available' do
        allow(described_class).to receive(:require).with('pg').and_raise(LoadError)

        expect {
          described_class.establish_connection(adapter: 'postgresql', config: config)
        }.to raise_error('pg gem not available. Please add it to your Gemfile.')
      end
    end

    context 'for unsupported adapter' do
      it 'raises ArgumentError' do
        expect {
          described_class.establish_connection(adapter: 'sqlite3', config: {})
        }.to raise_error(ArgumentError, 'Unsupported adapter: sqlite3')
      end
    end
  end

  describe '.test_connection' do
    context 'for MySQL' do
      let(:config) do
        {
          host: 'localhost',
          username: 'root',
          password: 'password',
          database: 'test_db'
        }
      end

      it 'tests MySQL connection successfully' do
        mock_client = instance_double('Mysql2::Client')
        mock_result = instance_double('Mysql2::Result')
        server_info = { version: '8.0.34' }

        allow(described_class).to receive(:establish_connection).and_return(mock_client)
        allow(mock_client).to receive(:query).with('SELECT 1 AS test').and_return(mock_result)
        allow(mock_result).to receive(:first).and_return({ 'test' => 1 })
        allow(mock_client).to receive(:server_info).and_return(server_info)
        allow(mock_client).to receive(:close)

        result = described_class.test_connection(adapter: 'mysql2', config: config)

        expect(result[:success]).to be true
        expect(result[:adapter]).to eq('mysql2')
        expect(result[:version]).to eq('8.0.34')
      end

      it 'handles MySQL connection failure' do
        allow(described_class).to receive(:establish_connection).and_raise(
          StandardError.new('Connection refused')
        )

        result = described_class.test_connection(adapter: 'mysql2', config: config)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Connection refused')
        expect(result[:adapter]).to eq('mysql2')
      end

      it 'closes connection after test' do
        mock_client = instance_double('Mysql2::Client')
        mock_result = instance_double('Mysql2::Result')

        allow(described_class).to receive(:establish_connection).and_return(mock_client)
        allow(mock_client).to receive(:query).and_return(mock_result)
        allow(mock_result).to receive(:first).and_return({ 'test' => 1 })
        allow(mock_client).to receive(:server_info).and_return({ version: '8.0.34' })

        expect(mock_client).to receive(:close)

        described_class.test_connection(adapter: 'mysql2', config: config)
      end
    end

    context 'for PostgreSQL' do
      let(:config) do
        {
          host: 'localhost',
          username: 'postgres',
          password: 'password',
          database: 'test_db'
        }
      end

      it 'tests PostgreSQL connection successfully' do
        mock_connection = instance_double('PG::Connection')
        mock_result = instance_double('PG::Result')

        allow(described_class).to receive(:establish_connection).and_return(mock_connection)
        allow(mock_connection).to receive(:exec).with('SELECT 1 AS test').and_return(mock_result)
        allow(mock_result).to receive(:first).and_return({ 'test' => '1' })
        allow(mock_connection).to receive(:server_version).and_return(140005)
        allow(mock_connection).to receive(:close)

        result = described_class.test_connection(adapter: 'postgresql', config: config)

        expect(result[:success]).to be true
        expect(result[:adapter]).to eq('postgresql')
        expect(result[:version]).to eq(140005)
      end

      it 'handles PostgreSQL connection failure' do
        allow(described_class).to receive(:establish_connection).and_raise(
          StandardError.new('Connection refused')
        )

        result = described_class.test_connection(adapter: 'postgresql', config: config)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Connection refused')
        expect(result[:adapter]).to eq('postgresql')
      end

      it 'closes connection after test' do
        mock_connection = instance_double('PG::Connection')
        mock_result = instance_double('PG::Result')

        allow(described_class).to receive(:establish_connection).and_return(mock_connection)
        allow(mock_connection).to receive(:exec).and_return(mock_result)
        allow(mock_result).to receive(:first).and_return({ 'test' => '1' })
        allow(mock_connection).to receive(:server_version).and_return(140005)

        expect(mock_connection).to receive(:close)

        described_class.test_connection(adapter: 'postgresql', config: config)
      end
    end

    context 'for unknown adapter' do
      it 'returns error result' do
        allow(described_class).to receive(:establish_connection).and_raise(
          ArgumentError.new('Unsupported adapter: unknown')
        )

        result = described_class.test_connection(adapter: 'unknown', config: {})

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Unsupported adapter: unknown')
      end
    end
  end

  describe '.connection_params' do
    context 'for MySQL' do
      it 'returns MySQL connection parameters with provided config' do
        config = { host: 'custom_host', port: 3307, username: 'custom_user', database: 'custom_db' }
        params = described_class.connection_params(adapter: 'mysql2', config: config)

        expect(params[:host]).to eq('custom_host')
        expect(params[:port]).to eq(3307)
        expect(params[:username]).to eq('custom_user')
        expect(params[:database]).to eq('custom_db')
        expect(params[:encoding]).to eq('utf8mb4')
        expect(params[:reconnect]).to be true
      end

      it 'uses environment variables as defaults' do
        ENV['DB_HOST'] = 'env_host'
        ENV['DB_PORT'] = '3308'
        ENV['DB_USERNAME'] = 'env_user'
        ENV['DB_PASSWORD'] = 'env_pass'
        ENV['DB_NAME'] = 'env_db'

        params = described_class.connection_params(adapter: 'mysql2', config: {})

        expect(params[:host]).to eq('env_host')
        expect(params[:port]).to eq(3308)
        expect(params[:username]).to eq('env_user')
        expect(params[:password]).to eq('env_pass')
        expect(params[:database]).to eq('env_db')

        ENV.delete('DB_HOST')
        ENV.delete('DB_PORT')
        ENV.delete('DB_USERNAME')
        ENV.delete('DB_PASSWORD')
        ENV.delete('DB_NAME')
      end

      it 'uses default values when config and env are not set' do
        params = described_class.connection_params(adapter: 'mysql2', config: {})

        expect(params[:host]).to eq('localhost')
        expect(params[:port]).to eq(3306)
        expect(params[:username]).to eq('root')
        expect(params[:database]).to eq('reline_production')
      end
    end

    context 'for PostgreSQL' do
      it 'returns PostgreSQL connection parameters with provided config' do
        config = { host: 'custom_host', port: 5433, username: 'custom_user', database: 'custom_db' }
        params = described_class.connection_params(adapter: 'postgresql', config: config)

        expect(params[:host]).to eq('custom_host')
        expect(params[:port]).to eq(5433)
        expect(params[:user]).to eq('custom_user')
        expect(params[:dbname]).to eq('custom_db')
      end

      it 'uses environment variables as defaults' do
        ENV['PG_HOST'] = 'pg_env_host'
        ENV['PG_PORT'] = '5434'
        ENV['PG_USER'] = 'pg_env_user'
        ENV['PG_PASSWORD'] = 'pg_env_pass'
        ENV['PG_DATABASE'] = 'pg_env_db'

        params = described_class.connection_params(adapter: 'postgresql', config: {})

        expect(params[:host]).to eq('pg_env_host')
        expect(params[:port]).to eq(5434)
        expect(params[:user]).to eq('pg_env_user')
        expect(params[:password]).to eq('pg_env_pass')
        expect(params[:dbname]).to eq('pg_env_db')

        ENV.delete('PG_HOST')
        ENV.delete('PG_PORT')
        ENV.delete('PG_USER')
        ENV.delete('PG_PASSWORD')
        ENV.delete('PG_DATABASE')
      end

      it 'uses default values when config and env are not set' do
        params = described_class.connection_params(adapter: 'postgresql', config: {})

        expect(params[:host]).to eq('localhost')
        expect(params[:port]).to eq(5432)
        expect(params[:user]).to eq('postgres')
        expect(params[:dbname]).to eq('reline_production')
      end
    end

    context 'for unsupported adapter' do
      it 'raises ArgumentError' do
        expect {
          described_class.connection_params(adapter: 'sqlite3', config: {})
        }.to raise_error(ArgumentError, 'Unsupported adapter: sqlite3')
      end
    end
  end

  describe 'private methods' do
    describe '.mysql_connection_params' do
      it 'merges config with environment defaults' do
        ENV['DB_HOST'] = 'env_host'
        config = { username: 'config_user', database: 'config_db' }

        params = described_class.send(:mysql_connection_params, config)

        expect(params[:host]).to eq('env_host')
        expect(params[:username]).to eq('config_user')
        expect(params[:database]).to eq('config_db')

        ENV.delete('DB_HOST')
      end
    end

    describe '.postgresql_connection_params' do
      it 'merges config with environment defaults' do
        ENV['PG_HOST'] = 'pg_env_host'
        config = { username: 'config_user', database: 'config_db' }

        params = described_class.send(:postgresql_connection_params, config)

        expect(params[:host]).to eq('pg_env_host')
        expect(params[:user]).to eq('config_user')
        expect(params[:dbname]).to eq('config_db')

        ENV.delete('PG_HOST')
      end
    end

    describe '.test_mysql_connection' do
      it 'executes test query and returns result' do
        mock_client = instance_double('Mysql2::Client')
        mock_result = instance_double('Mysql2::Result')
        server_info = { version: '8.0.34' }

        allow(mock_client).to receive(:query).with('SELECT 1 AS test').and_return(mock_result)
        allow(mock_result).to receive(:first).and_return({ 'test' => 1 })
        allow(mock_client).to receive(:server_info).and_return(server_info)

        result = described_class.send(:test_mysql_connection, mock_client)

        expect(result[:success]).to be true
        expect(result[:adapter]).to eq('mysql2')
        expect(result[:version]).to eq('8.0.34')
      end
    end

    describe '.test_postgresql_connection' do
      it 'executes test query and returns result' do
        mock_connection = instance_double('PG::Connection')
        mock_result = instance_double('PG::Result')

        allow(mock_connection).to receive(:exec).with('SELECT 1 AS test').and_return(mock_result)
        allow(mock_result).to receive(:first).and_return({ 'test' => '1' })
        allow(mock_connection).to receive(:server_version).and_return(140005)

        result = described_class.send(:test_postgresql_connection, mock_connection)

        expect(result[:success]).to be true
        expect(result[:adapter]).to eq('postgresql')
        expect(result[:version]).to eq(140005)
      end
    end
  end
end
