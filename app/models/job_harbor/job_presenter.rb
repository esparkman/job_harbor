# frozen_string_literal: true

module JobHarbor
  class JobPresenter
    include ActionView::Helpers::DateHelper

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
      payload = filtered_payload
      arguments = payload["arguments"] if payload.is_a?(Hash)
      arguments.is_a?(Array) ? arguments : []
    end

    def formatted_arguments
      JSON.pretty_generate(job_arguments)
    end

    def formatted_payload
      JSON.pretty_generate(filtered_payload)
    end

    def error_message
      filtered_error_part("message")
    end

    def error_class
      parsed_error&.dig("exception_class")
    end

    def error_backtrace
      Array(filtered_error_part("backtrace")).join("\n")
    end

    def failed_at
      @failed_execution&.created_at
    end

    def worker_name
      @job.claimed_execution&.process&.name
    end

    # Active Job serializes the number of earlier runs, so the attempt is one more.
    def execution_count
      payload = serialized_payload
      executions = payload["executions"] if payload.is_a?(Hash)
      executions.to_i + 1
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
      JobStatus.find(status)&.retryable || false
    end

    def can_discard?
      JobStatus.find(status)&.discardable || false
    end

    def to_param
      id.to_s
    end

    private

    def filtered_payload
      @filtered_payload ||= SensitiveValueFilter.filter(serialized_payload)
    end

    # Messages and backtraces go through the same filter so a host Proc can scrub them.
    def filtered_error_part(key)
      error = parsed_error
      return nil unless error

      @filtered_error ||= SensitiveValueFilter.filter("message" => error["message"], "backtrace" => error["backtrace"])
      @filtered_error.is_a?(Hash) ? @filtered_error[key] : @filtered_error
    end

    def parsed_error
      error = @failed_execution&.error
      return nil unless error

      error.is_a?(String) ? JSON.parse(error) : error
    rescue JSON::ParserError
      { "message" => error }
    end

    def determine_status
      JobStatus.by_precedence.each do |status|
        return status.key if execution_for(status.execution_association)
      end

      @job.finished_at.present? ? "finished" : "unknown"
    end

    def execution_for(association)
      association == :failed_execution ? @failed_execution : @job.public_send(association)
    end

    class << self
      def find(id)
        new(SolidQueue::Job.preload(*JobStatus.execution_associations).find(id))
      end
    end
  end
end
