# frozen_string_literal: true

module JobHarbor
  class FailureStats
    WINDOW = 24.hours
    LOW_THRESHOLD = 5
    MEDIUM_THRESHOLD = 20

    def initialize(window: WINDOW)
      @window = window
      @cutoff = Time.current - @window
    end

    def stats
      @stats ||= calculate_stats
    end

    def self.rate_badge_class(rate)
      case rate
      when 0...LOW_THRESHOLD
        "sqd-rate-low"
      when LOW_THRESHOLD...MEDIUM_THRESHOLD
        "sqd-rate-medium"
      else
        "sqd-rate-high"
      end
    end

    private

    def calculate_stats
      # Get all jobs in the window period
      recent_jobs = SolidQueue::Job.where("created_at >= ?", @cutoff)

      # Group by class_name and calculate totals
      job_counts = recent_jobs.group(:class_name).count

      # Get failed job counts (jobs that have failed executions)
      failed_job_ids = SolidQueue::FailedExecution
        .joins(:job)
        .where("solid_queue_jobs.created_at >= ?", @cutoff)
        .pluck(:job_id)

      failed_counts = SolidQueue::Job
        .where(id: failed_job_ids)
        .group(:class_name)
        .count

      # Build stats array
      job_counts.map do |class_name, total|
        failed = failed_counts[class_name] || 0
        rate = total > 0 ? (failed.to_f / total * 100).round(1) : 0.0

        {
          class_name: class_name,
          total: total,
          failed: failed,
          rate: rate
        }
      end.sort_by { |s| -s[:rate] }
    end
  end
end
