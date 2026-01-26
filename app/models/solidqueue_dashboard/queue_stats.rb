# frozen_string_literal: true

module SolidqueueDashboard
  class QueueStats
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def pending_count
      SolidQueue::ReadyExecution.where(queue_name: @name).count
    end

    def scheduled_count
      SolidQueue::ScheduledExecution
        .joins(:job)
        .where(solid_queue_jobs: { queue_name: @name })
        .count
    end

    def in_progress_count
      SolidQueue::ClaimedExecution
        .joins(:job)
        .where(solid_queue_jobs: { queue_name: @name })
        .count
    end

    def failed_count
      SolidQueue::FailedExecution
        .joins(:job)
        .where(solid_queue_jobs: { queue_name: @name })
        .count
    end

    def total_count
      pending_count + scheduled_count + in_progress_count + failed_count
    end

    def paused?
      SolidQueue::Pause.exists?(queue_name: @name)
    end

    def pause!
      SolidQueue::Pause.create!(queue_name: @name) unless paused?
    end

    def resume!
      SolidQueue::Pause.where(queue_name: @name).delete_all
    end

    def to_param
      @name
    end

    class << self
      def all
        queue_names.map { |name| new(name) }
      end

      def find(name)
        new(name) if queue_names.include?(name)
      end

      private

      def queue_names
        # Get all unique queue names from jobs and ready executions
        job_queues = SolidQueue::Job.distinct.pluck(:queue_name)
        ready_queues = SolidQueue::ReadyExecution.distinct.pluck(:queue_name)
        paused_queues = SolidQueue::Pause.distinct.pluck(:queue_name)

        (job_queues + ready_queues + paused_queues).uniq.compact.sort
      end
    end
  end
end
