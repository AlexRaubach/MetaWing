source 'https://rubygems.org'
ruby '~> 3.1.3'

# core

gem 'pg'
gem 'puma'
gem 'rails', '~> 6.1'

# views

gem 'bootstrap'
gem 'coffee-rails'
gem 'font-awesome-rails'
gem 'haml'
gem 'sassc-rails'
gem 'uglifier'

# core libs

gem 'devise'
gem 'exception_notification'
gem 'jbuilder'
gem 'jquery-rails'
# gem 'webpacker'

# Add some gems so rails 6 runs on 3.1.3
gem 'net-imap', require: false
gem 'net-pop', require: false
gem 'net-smtp', require: false

# additional libs

gem 'chartkick'
gem 'chunky_png', require: false
gem 'execjs'
gem 'git'
gem 'groupdate', require: 'groupdate'
gem 'httparty'
gem 'nokogiri'
gem 'oily_png'
gem 'redcarpet'

gem 'turbolinks'

source 'https://rails-assets.org' do
  gem 'rails-assets-tether', '>= 1.3.3'
end

# use scout for monitoring
# gem 'scout_apm'

group :development, :test do
  gem 'pry', require: false
  gem 'rspec-rails'
  gem 'seed_dump'
end

group :development do
  gem 'listen'
  gem 'web-console'
end
