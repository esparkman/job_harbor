source "https://rubygems.org"

# Specify your gem's dependencies in job_harbor.gemspec.
gemspec

gem "puma"

gem "sqlite3"

gem "propshaft"

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Security scanners run by bin/ci and the CI security job
gem "bundler-audit", require: false
gem "brakeman", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
