# frozen_string_literal: true

module JobHarbor
  class QueueStats
    # Solid Queue's queue_name columns are plain strings; 255 fits every adapter's default string limit.
    MAX_NAME_LENGTH = 255

    attr_reader :name

    def initialize(name, oldest_ready_at: nil)
      @name = name
      @oldest_ready_at = oldest_ready_at if oldest_ready_at
    end

    def count(status) = status.count(queue_name: @name)

    delegate :paused?, to: :solid_queue

    def oldest_ready_at
      return @oldest_ready_at if defined?(@oldest_ready_at)

      @oldest_ready_at = SolidQueue::ReadyExecution.where(queue_name: @name).minimum(:created_at)
    end

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
        names.map { |name| new(name) }
      end

      def find(name)
        new(name) if SolidQueue::Job.exists?(queue_name: name) || SolidQueue::Pause.exists?(queue_name: name)
      end

      # A paused queue's wait only grows, so it would always win.
      def longest_waiting
        name, oldest_ready_at = SolidQueue::ReadyExecution.where.not(queue_name: SolidQueue::Pause.select(:queue_name))
          .order(:created_at, :id).pick(:queue_name, :created_at)
        new(name, oldest_ready_at:) if name
      end

      def names
        # Every queue that has a job, plus paused queues that have no jobs
        (DistinctJobValues.of(:queue_name) | SolidQueue::Pause.pluck(:queue_name)).sort
      end
    end
  end
end
