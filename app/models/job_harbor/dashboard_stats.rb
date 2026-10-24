# frozen_string_literal: true

module JobHarbor
  class DashboardStats
    attr_reader :status_counts, :workers_count, :queues_count, :throughput_per_hour,
                :recent_failures

    def initialize
      calculate_stats
    end

    private

    def calculate_stats
      @status_counts = JobStatus.all.to_h { |status| [ status.key, status.finished? ? finished_jobs_count : status.count ] }
      @workers_count = active_workers_count
      @queues_count = queues_count_calc
      @throughput_per_hour = calculate_throughput
      @recent_failures = fetch_recent_failures
    end

    def finished_jobs_count
      SolidQueue::Job.where("finished_at > ?", 24.hours.ago).count
    end

    def active_workers_count
      Processes.live_workers.count
    end

    def queues_count_calc
      SolidQueue::Job.distinct.count(:queue_name)
    end

    def calculate_throughput
      SolidQueue::Job.where("finished_at > ?", 1.hour.ago).count
    end

    def fetch_recent_failures
      SolidQueue::FailedExecution
        .includes(:job)
        .order(created_at: :desc)
        .limit(5)
        .map { |fe| JobPresenter.new(fe.job, failed_execution: fe) }
    end
  end
end
