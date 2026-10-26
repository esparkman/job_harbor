# frozen_string_literal: true

module JobHarbor
  class QueueStats
    # Solid Queue's queue_name columns are plain strings; 255 fits every adapter's default string limit.
    MAX_NAME_LENGTH = 255

    attr_reader :name

    def initialize(name)
      @name = name
    end

    def count(status) = status.count(queue_name: @name)

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
        names.map { |name| new(name) }
      end

      def find(name)
        new(name) if SolidQueue::Job.exists?(queue_name: name) || SolidQueue::Pause.exists?(queue_name: name)
      end

      def names
        # Every queue that has a job, plus paused queues that have no jobs
        (SolidQueue::Job.distinct.pluck(:queue_name) | SolidQueue::Pause.pluck(:queue_name)).sort
      end
    end
  end
end
