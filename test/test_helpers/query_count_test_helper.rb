module QueryCountTestHelper
  TRANSACTION_CONTROL = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)\b/i

  # SQL the block sent to the database, minus schema lookups, transaction control and query-cache hits.
  def count_queries(&block)
    queries = []
    counter = lambda do |*, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached] || payload[:sql].match?(TRANSACTION_CONTROL)

      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    queries
  end
end
