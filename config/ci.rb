# Run using bin/ci

CI.run do
  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem vulnerability audit", "bundle exec bundler-audit check --update"
  step "Security: Brakeman code analysis", "bundle exec brakeman --no-pager -q"

  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails app:db:seed:replant"
end
