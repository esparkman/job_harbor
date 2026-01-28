# frozen_string_literal: true

module JobHarbor
  class DashboardStats
    attr_reader :pending_count, :scheduled_count, :in_progress_count,
                :failed_count, :blocked_count, :finished_count,
                :workers_count, :queues_count, :throughput_per_hour,
                :recent_failures

    def initialize
      calculate_stats
    end

    def total_jobs
      pending_count + scheduled_count + in_progress_count + failed_count + blocked_count
    end

    private

    def calculate_stats
      @pending_count = ready_executions_count
      @scheduled_count = scheduled_executions_count
      @in_progress_count = claimed_executions_count
      @failed_count = failed_executions_count
      @blocked_count = blocked_executions_count
      @finished_count = finished_jobs_count
      @workers_count = active_workers_count
      @queues_count = queues_count_calc
      @throughput_per_hour = calculate_throughput
      @recent_failures = fetch_recent_failures
    end

    def ready_executions_count
      SolidQueue::ReadyExecution.count
    end

    def scheduled_executions_count
      SolidQueue::ScheduledExecution.count
    end

    def claimed_executions_count
      SolidQueue::ClaimedExecution.count
    end

    def failed_executions_count
      SolidQueue::FailedExecution.count
    end

    def blocked_executions_count
      SolidQueue::BlockedExecution.count
    end

    def finished_jobs_count
      # Count jobs finished in the last 24 hours
      if SolidQueue::Job.column_names.include?("finished_at")
        SolidQueue::Job.where("finished_at > ?", 24.hours.ago).count
      else
        0
      end
    end

    def active_workers_count
      SolidQueue::Process.where("last_heartbeat_at > ?", 5.minutes.ago).count
    end

    def queues_count_calc
      SolidQueue::Queue.count
    rescue
      # Fallback: count unique queue names from jobs
      SolidQueue::Job.distinct.count(:queue_name)
    end

    def calculate_throughput
      # Jobs finished in the last hour
      if SolidQueue::Job.column_names.include?("finished_at")
        SolidQueue::Job.where("finished_at > ?", 1.hour.ago).count
      else
        0
      end
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
