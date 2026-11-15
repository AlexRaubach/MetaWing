source 'https://rubygems.org'
ruby '3.4.7'

# core

gem 'pg'
gem 'puma'
gem 'rails', '~> 7.2'

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
# 3.x rejects the quirks_mode option ActiveSupport 7.2 passes to JSON.generate,
# which breaks every to_json / render json: call
gem 'json', '~> 2.19'
# No longer loaded implicitly as of Ruby 3.4; used by the show controllers
gem 'ostruct'
# gem 'webpacker'

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
