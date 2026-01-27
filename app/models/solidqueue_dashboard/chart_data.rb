# frozen_string_literal: true

module SolidqueueDashboard
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
      @interval = @range[:interval]
      @cutoff = Time.current - @duration
    end

    def self.available_ranges
      RANGES.map { |key, config| { value: key, label: config[:label] } }
    end

    def series
      @series ||= calculate_series
    end

    private

    def calculate_series
      buckets = generate_time_buckets
      labels = buckets.map { |t| format_label(t) }

      completed = count_by_bucket(completed_jobs, :finished_at, buckets)
      failed = count_by_bucket(failed_jobs, :created_at, buckets)
      enqueued = count_by_bucket(enqueued_jobs, :created_at, buckets)

      {
        labels: labels,
        completed: completed,
        failed: failed,
        enqueued: enqueued
      }
    end

    def generate_time_buckets
      buckets = []
      current = @cutoff
      while current <= Time.current
        buckets << current
        current += @interval
      end
      buckets
    end

    def format_label(time)
      if @duration <= 1.hour
        time.strftime("%H:%M")
      elsif @duration <= 24.hours
        time.strftime("%H:%M")
      else
        time.strftime("%b %d")
      end
    end

    def count_by_bucket(scope, time_field, buckets)
      # Get counts grouped by time bucket
      counts = scope
        .where("#{time_field} >= ?", @cutoff)
        .group_by_period(@interval, time_field)

      # Map to bucket array
      buckets.map do |bucket_start|
        bucket_end = bucket_start + @interval
        counts.count { |time, _| time >= bucket_start && time < bucket_end }
      end
    rescue => e
      # Fallback to simple counting if group_by_period isn't available
      buckets.map do |bucket_start|
        bucket_end = bucket_start + @interval
        scope.where("#{time_field} >= ? AND #{time_field} < ?", bucket_start, bucket_end).count
      end
    end

    def completed_jobs
      SolidQueue::Job.where.not(finished_at: nil)
    end

    def failed_jobs
      SolidQueue::FailedExecution.all
    end

    def enqueued_jobs
      SolidQueue::Job.all
    end

    def group_by_period(scope, interval, time_field)
      # Simple implementation - group records by time bucket
      scope.pluck(time_field).group_by do |time|
        time.to_i / interval.to_i * interval.to_i
      end.transform_keys { |ts| Time.at(ts) }
    end
  end
end
