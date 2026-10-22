# frozen_string_literal: true

module JobHarbor
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

    def blocked_count
      SolidQueue::BlockedExecution.where(queue_name: @name).count
    end

    delegate :paused?, to: :solid_queue

    def pause
      solid_queue.pause
    end

    def resume
      solid_queue.resume
    end

    def to_param
      @name
    end

    private

    def solid_queue
      @solid_queue ||= SolidQueue::Queue.find_by_name(@name)
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
        # Every queue that has a job, plus queues that are paused before any job arrives
        job_queues = SolidQueue::Job.distinct.pluck(:queue_name)
        paused_queues = SolidQueue::Pause.distinct.pluck(:queue_name)

        (job_queues + paused_queues).uniq.compact.sort
      end
    end
  end
end
