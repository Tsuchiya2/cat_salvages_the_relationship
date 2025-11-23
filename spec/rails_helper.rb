require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures').to_s]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
end

# SimpleCov configuration
if ENV['CI'] == 'true' || ENV['COVERAGE'] == 'true'
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.start 'rails' do
    # Set minimum coverage threshold
    minimum_coverage 88

    # Filters - exclude these directories from coverage
    add_filter '/spec/'
    add_filter '/config/'
    add_filter '/vendor/'
    add_filter '/test/'

    # Coverage output formatters
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::HTMLFormatter,
                                                         SimpleCov::Formatter::Console
                                                       ])

    # Track files even if they are not loaded
    track_files '{app,lib}/**/*.rb'
  end
end

# Load support files
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }
