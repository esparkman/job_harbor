# frozen_string_literal: true

module JobHarbor
  class JobPresenter
    include ActionView::Helpers::DateHelper

    # In precedence order: the first execution a job holds decides its status.
    EXECUTION_STATUSES = {
      failed_execution: "failed",
      claimed_execution: "in_progress",
      blocked_execution: "blocked",
      scheduled_execution: "scheduled",
      ready_execution: "pending"
    }.freeze

    LIKE_ESCAPE = "!"
    UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    delegate :id, :created_at, :queue_name, :priority,
             :active_job_id, :scheduled_at, :finished_at, :discard,
             to: :@job

    def initialize(job, failed_execution: nil)
      @job = job
      @failed_execution = failed_execution || job.failed_execution
    end

    def class_name
      @job.class_name
    end

    def status
      @status ||= determine_status
    end

    # Solid Queue stores the whole serialized Active Job payload, not just the arguments.
    def serialized_payload
      @job.arguments
    end

    def job_arguments
      payload = serialized_payload
      arguments = payload["arguments"] if payload.is_a?(Hash)
      arguments.is_a?(Array) ? arguments : []
    end

    def formatted_arguments
      JSON.pretty_generate(job_arguments)
    end

    def formatted_payload
      JSON.pretty_generate(serialized_payload)
    end

    def error_message
      parsed_error&.dig("message")
    end

    def error_class
      parsed_error&.dig("exception_class")
    end

    def error_backtrace
      parsed_error&.dig("backtrace")&.join("\n")
    end

    def failed_at
      @failed_execution&.created_at
    end

    def worker_name
      @job.claimed_execution&.process&.name
    end

    def execution_count
      payload = serialized_payload
      executions = payload["executions"] if payload.is_a?(Hash)
      [ executions.to_i, 1 ].max
    end

    def running_duration
      claimed = @job.claimed_execution
      return nil unless claimed && status == "in_progress"

      distance_of_time_in_words(claimed.created_at, Time.current)
    end

    def relative_created_at
      time_ago_in_words(@job.created_at) + " ago"
    end

    def retry_badge
      count = execution_count
      return nil if count <= 1

      "(x#{count})"
    end

    def can_retry?
      status == "failed"
    end

    def can_discard?
      %w[pending scheduled failed blocked].include?(status)
    end

    def to_param
      id.to_s
    end

    private

    def parsed_error
      error = @failed_execution&.error
      return nil unless error

      error.is_a?(String) ? JSON.parse(error) : error
    rescue JSON::ParserError
      { "message" => error }
    end

    def determine_status
      EXECUTION_STATUSES.each do |association, status|
        return status if execution_for(association)
      end

      @job.finished_at.present? ? "finished" : "unknown"
    end

    def execution_for(association)
      association == :failed_execution ? @failed_execution : @job.public_send(association)
    end

    class << self
      def find(id)
        new(SolidQueue::Job.preload(*EXECUTION_STATUSES.keys).find(id))
      end

      def all_with_status(status = nil, page: 1, per_page: 25, class_name: nil, queue_name: nil)
        jobs = scope_for(status)
        jobs = apply_filters(jobs, class_name: class_name, queue_name: queue_name)
        paginate(jobs, page: page, per_page: per_page)
      end

      def apply_filters(scope, class_name: nil, queue_name: nil)
        scope = scope.where(class_name: class_name) if class_name.present?
        scope = scope.where(queue_name: queue_name) if queue_name.present?
        scope
      end

      def search(query, page: 1, per_page: 25)
        paginate(search_scope(query), page: page, per_page: per_page)
      end

      private

      def scope_for(status)
        if status.to_s == "finished"
          SolidQueue::Job.where.not(finished_at: nil)
        elsif (association = EXECUTION_STATUSES.key(status.to_s))
          SolidQueue::Job.joins(association)
        else
          SolidQueue::Job.all
        end
      end

      def search_scope(query)
        jobs = SolidQueue::Job
        pattern = "%#{jobs.sanitize_sql_like(query, LIKE_ESCAPE)}%"
        scope = jobs.where("class_name LIKE :pattern ESCAPE :escape OR arguments LIKE :pattern ESCAPE :escape",
          pattern: pattern, escape: LIKE_ESCAPE)
        scope = scope.or(jobs.where(id: query)) if query.match?(/\A\d+\z/)
        scope = scope.or(jobs.where(active_job_id: query)) if query.match?(UUID_FORMAT)
        scope
      end

      def paginate(scope, page:, per_page:)
        page = [ page.to_i, 1 ].max
        offset = (page - 1) * per_page
        total = scope.count

        jobs = scope.preload(*EXECUTION_STATUSES.keys).order(id: :desc).limit(per_page).offset(offset).map { |job| new(job) }
        [ PageInfo.new(page: page, per_page: per_page, count: total), jobs ]
      end
    end
  end
end
