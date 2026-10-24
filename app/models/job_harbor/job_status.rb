# frozen_string_literal: true

module JobHarbor
  # The one place that knows which statuses a job can have, in display order.
  class JobStatus < Data.define(:key, :label, :color, :execution, :retryable, :discardable, :bulk)
    def self.build(key, label, color, execution, retryable: false, discardable: false, bulk: false)
      new(key: key, label: label, color: color, execution: execution, retryable: retryable, discardable: discardable, bulk: bulk)
    end

    # A job holding several executions takes the status of the first of these.
    PRECEDENCE = %w[failed in_progress blocked scheduled pending].freeze

    ALL = [
      build("pending", "Pending", "sky", :ready_execution, discardable: true),
      build("scheduled", "Scheduled", "yellow", :scheduled_execution, discardable: true),
      build("in_progress", "In Progress", "amber", :claimed_execution),
      build("failed", "Failed", "red", :failed_execution, retryable: true, discardable: true, bulk: true),
      build("blocked", "Blocked", "zinc", :blocked_execution, discardable: true, bulk: true),
      build("finished", "Finished", "green", nil)
    ].freeze

    class << self
      def all
        ALL
      end

      def find(key)
        ALL.find { |status| status.key == key.to_s }
      end

      def keys
        ALL.map(&:key)
      end

      # Statuses a job can hold an execution for, strongest first.
      def by_precedence
        PRECEDENCE.map { |key| find(key) }
      end

      def executions
        ALL.filter_map(&:execution)
      end
    end

    def to_s
      key
    end

    def finished?
      execution.nil?
    end

    def badge_class
      "badge-#{color}"
    end

    def circle_class
      "circle-#{color}"
    end

    def path_helper
      :"#{key}_jobs_path"
    end

    def route_name
      :"#{key}_jobs"
    end

    def execution_class
      SolidQueue.const_get(execution.to_s.camelize) if execution
    end

    def jobs
      finished? ? SolidQueue::Job.where.not(finished_at: nil) : SolidQueue::Job.joins(execution)
    end

    # Counts the execution rows themselves, which skips the join `jobs` needs.
    def count
      execution_class ? execution_class.count : jobs.count
    end
  end
end
