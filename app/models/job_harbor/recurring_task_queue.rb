# frozen_string_literal: true

module JobHarbor
  class RecurringTaskQueue
    def initialize(task)
      @task = task
    end

    # SQ stores queue_name only when recurring.yml sets one; otherwise the job class's queue_as decides.
    def name
      @task.queue_name.presence || job_class_queue_name
    end

    private

    # A queue_as block may read arguments we don't pass, so a raising block means we can't know the queue.
    def job_class_queue_name
      job_class&.new&.queue_name
    rescue StandardError
      nil
    end

    # Mirrors SQ's RecurringTask#job_class: a command task runs on SQ's default job class.
    def job_class
      return SolidQueue::RecurringTask.default_job_class if @task.class_name.blank?

      klass = @task.class_name.safe_constantize
      klass if klass.is_a?(Class) && klass < ActiveJob::Base
    end
  end
end
