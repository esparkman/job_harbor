# frozen_string_literal: true

module JobHarbor
  class FailureStats
    WINDOW = 24.hours

    def stats
      @stats ||= calculate_stats
    end

    private

    def calculate_stats
      since = Time.current - WINDOW
      recent_jobs = SolidQueue::Job.where(created_at: since..)

      totals = recent_jobs.group(:class_name).count
      failures = recent_jobs.joins(:failed_execution).group(:class_name).count

      totals.map do |class_name, total|
        failed = failures.fetch(class_name, 0)

        { class_name: class_name, total: total, failed: failed, rate: (failed.to_f / total * 100).round(1) }
      end.sort_by { |stat| -stat[:rate] }
    end
  end
end
