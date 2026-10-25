# frozen_string_literal: true

module JobHarbor
  class ChartData
    RANGES = {
      "15m" => { duration: 15.minutes, interval: 1.minute, label: "15 min" },
      "1h" => { duration: 1.hour, interval: 5.minutes, label: "1 hour" },
      "6h" => { duration: 6.hours, interval: 30.minutes, label: "6 hours" },
      "24h" => { duration: 24.hours, interval: 1.hour, label: "24 hours" },
      "7d" => { duration: 7.days, interval: 6.hours, label: "7 days" }
    }.freeze

    def initialize(range: "24h")
      @range = RANGES[range] || RANGES["24h"]
      @duration = @range[:duration]
      @interval = @range[:interval].to_i
      @cutoff = Time.current - @duration
    end

    def self.available_ranges
      RANGES.map { |key, config| { value: key, label: config[:label] } }
    end

    def series
      @series ||= {
        labels: labels,
        completed: counts_per_bucket(SolidQueue::Job, :finished_at),
        failed: counts_per_bucket(SolidQueue::FailedExecution, :created_at),
        enqueued: counts_per_bucket(SolidQueue::Job, :created_at)
      }
    end

    private

    def bucket_count
      @duration.to_i / @interval
    end

    def bucket_starts
      Array.new(bucket_count) { |index| @cutoff + index * @interval }
    end

    # Clock labels repeat or skip an hour across a daylight-saving change, so a series that spans one names the zone.
    def labels
      starts = bucket_starts
      return starts.map { |time| time.strftime("%b %d") } if @duration > 24.hours

      pattern = starts.map(&:utc_offset).uniq.one? ? "%H:%M" : "%H:%M %Z"
      starts.map { |time| time.strftime(pattern) }
    end

    # One row of SUM(CASE ...) per series: ANSI SQL, so it needs no per-database date truncation.
    def counts_per_bucket(model, time_field)
      column = "#{model.quoted_table_name}.#{model.connection.quote_column_name(time_field)}"
      sums = bucket_starts.each_with_index.map { |start, index| bucket_sum(model, column, start, last: index == bucket_count - 1) }

      model.where(time_field => @cutoff..).pick(*sums).map(&:to_i)
    end

    # The last bucket is open-ended so a job stamped at the instant of the query still counts.
    def bucket_sum(model, column, start, last:)
      within = last ? "#{column} >= ?" : "#{column} >= ? AND #{column} < ?"
      binds = last ? [ start ] : [ start, start + @interval ]

      Arel.sql(model.sanitize_sql_array([ "SUM(CASE WHEN #{within} THEN 1 ELSE 0 END)", *binds ]))
    end
  end
end
