source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.6'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 8.1.1'
# Use Puma as the app server
gem 'puma', '>= 6.0'
# Use Propshaft for asset pipeline
gem 'propshaft'
# Use jsbundling-rails with esbuild
gem 'jsbundling-rails'
# Use cssbundling-rails with bootstrap
gem 'cssbundling-rails'
# Hotwire's SPA-like page accelerator
gem 'turbo-rails'
# Hotwire's modest JavaScript framework
gem 'stimulus-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false
gem 'slim-rails'
gem 'sorcery'
gem 'enum_help'
gem 'line-bot-api', '~> 2.0'
gem 'pundit'
gem 'prometheus-client', '~> 4.0'
gem 'lograge', '~> 0.14'
gem 'request_store', '~> 1.5'

group :production do
  gem 'pg'
end

group :development, :test do
  # Use mysql as the database for Active Record
  gem 'mysql2', '~> 0.5'
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rubocop-performance'
  gem 'rubocop-rspec'
  gem 'pry-byebug'
  # Security scanners
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'rack-mini-profiler'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # Note: Spring is deprecated in Rails 8, consider removing if not needed
  gem 'letter_opener_web'
  gem 'traceroute'
  gem 'bullet'
  gem 'better_errors'
end

group :test do
  gem 'capybara'
  gem 'faker'
  gem 'webdrivers'
  gem 'simplecov'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
