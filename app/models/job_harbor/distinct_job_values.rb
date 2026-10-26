# frozen_string_literal: true

module JobHarbor
  module DistinctJobValues
    COLUMNS = %w[queue_name class_name].freeze # each leads an index

    class << self
      # Loose index scan: one index seek per distinct value, where DISTINCT on PostgreSQL and SQLite reads every row.
      # Sorted in Ruby so the order matches what the pages always showed, whatever the collation.
      def of(column)
        column = column.to_s
        raise ArgumentError, "unsupported column: #{column}" unless COLUMNS.include?(column)

        SolidQueue::Job.with_connection do |connection|
          # MySQL already runs DISTINCT as a loose index scan, and caps a recursive CTE at 1000 rows.
          if connection.adapter_name.match?(/mysql|trilogy/i)
            SolidQueue::Job.distinct.pluck(column)
          else
            connection.select_values(loose_scan_sql(connection, column))
          end.sort
        end
      end

      private

      def loose_scan_sql(connection, column)
        table = SolidQueue::Job.quoted_table_name
        name = connection.quote_column_name(column)

        <<~SQL.squish
          WITH RECURSIVE distinct_values(value) AS (
            SELECT MIN(#{name}) FROM #{table}
            UNION ALL
            SELECT (SELECT MIN(#{name}) FROM #{table} WHERE #{name} > distinct_values.value)
            FROM distinct_values WHERE distinct_values.value IS NOT NULL
          )
          SELECT value FROM distinct_values WHERE value IS NOT NULL
        SQL
      end
    end
  end
end
