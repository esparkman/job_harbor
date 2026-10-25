class ThrottledImportJob < ApplicationJob
  limits_concurrency key: ->(account) { account }

  def perform(*) = nil
end
