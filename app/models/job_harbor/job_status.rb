# frozen_string_literal: true

module JobHarbor
  # The one place that knows which statuses a job can have, in display order.
  JobStatus = Data.define(:key, :label, :color, :execution_association, :retryable, :discardable, :bulk_actions) do
    def initialize(retryable: false, discardable: false, bulk_actions: false, **) = super

    class << self
      def all
        JobStatus::ALL
      end

      def find(key)
        all.find { |status| status.key == key.to_s }
      end

      def keys
        all.map(&:key)
      end

      # Statuses a job can hold an execution for, strongest first.
      def by_precedence
        JobStatus::PRECEDENCE.map { |key| find(key) }
      end

      def execution_associations
        all.filter_map(&:execution_association)
      end
    end

    def to_s
      key
    end

    def finished?
      execution_association.nil?
    end

    # Retrying every job of a status at once is only offered where the status has bulk actions.
    def bulk_retry?
      bulk_actions && retryable
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
      SolidQueue.const_get(execution_association.to_s.camelize) if execution_association
    end

    def jobs
      finished? ? SolidQueue::Job.where.not(finished_at: nil) : SolidQueue::Job.joins(execution_association)
    end

    # Counts the execution rows themselves, which skips the join `jobs` needs.
    def count
      execution_class ? execution_class.count : jobs.count
    end
  end

  class JobStatus
    # A job holding several executions takes the status of the first of these.
    PRECEDENCE = %w[failed in_progress blocked scheduled pending].freeze

    ALL = [
      new(key: "pending", label: "Pending", color: "sky", execution_association: :ready_execution, discardable: true),
      new(key: "scheduled", label: "Scheduled", color: "yellow", execution_association: :scheduled_execution, discardable: true),
      new(key: "in_progress", label: "In Progress", color: "amber", execution_association: :claimed_execution),
      new(key: "failed", label: "Failed", color: "red", execution_association: :failed_execution,
        retryable: true, discardable: true, bulk_actions: true),
      new(key: "blocked", label: "Blocked", color: "zinc", execution_association: :blocked_execution,
        discardable: true, bulk_actions: true),
      new(key: "finished", label: "Finished", color: "green", execution_association: nil)
    ].freeze
  end
end
