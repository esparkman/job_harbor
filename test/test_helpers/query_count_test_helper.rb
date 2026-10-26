module QueryCountTestHelper
  def capture_sql(&block)
    queries = []
    counter = lambda do |*, payload|
      next if payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])

      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    queries
  end

  # Array#- drops every copy, so an N+1 would show up empty.
  def sql_growth(fewer, more)
    before = fewer.tally
    more.tally.filter_map do |sql, count|
      grown = count - before.fetch(sql, 0)
      "#{grown} more: #{sql}" if grown.positive?
    end.join("\n")
  end
end
