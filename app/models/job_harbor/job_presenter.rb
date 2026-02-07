# frozen_string_literal: true

require "ostruct"

module JobHarbor
  class JobPresenter
    include ActionView::Helpers::DateHelper

    delegate :id, :created_at, :updated_at, :queue_name, :priority,
             :active_job_id, :arguments, :scheduled_at, :finished_at,
             to: :@job

    def initialize(job, failed_execution: nil, claimed_execution: nil)
      @job = job
      @failed_execution = failed_execution
      @claimed_execution = claimed_execution
    end

    def class_name
      @job.class_name
    end

    def status
      @status ||= determine_status
    end

    def arguments_preview
      args = parsed_arguments
      return "No arguments" if args.empty?

      preview = args.to_json
      preview.length > 100 ? "#{preview[0..100]}..." : preview
    end

    def parsed_arguments
      JSON.parse(@job.arguments.to_s)
    rescue JSON::ParserError
      @job.arguments
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
      @claimed_execution&.process&.name
    end

    def execution_count
      args = parsed_arguments
      return 1 unless args.is_a?(Hash)

      (args["executions"] || args[:executions] || 1).to_i
    end

    def running_duration
      return nil unless status == "in_progress"

      claimed = @claimed_execution || SolidQueue::ClaimedExecution.find_by(job_id: @job.id)
      return nil unless claimed

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

    # ActiveModel compatibility
    def model_name
      ActiveModel::Name.new(self.class, nil, "Job")
    end

    def persisted?
      true
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
      return "failed" if has_failed_execution?
      return "in_progress" if has_claimed_execution?
      return "blocked" if has_blocked_execution?
      return "scheduled" if has_scheduled_execution?
      return "pending" if has_ready_execution?
      return "finished" if @job.finished_at.present?

      "unknown"
    end

    def has_failed_execution?
      @failed_execution.present? || SolidQueue::FailedExecution.exists?(job_id: @job.id)
    end

    def has_claimed_execution?
      @claimed_execution.present? || SolidQueue::ClaimedExecution.exists?(job_id: @job.id)
    end

    def has_blocked_execution?
      SolidQueue::BlockedExecution.exists?(job_id: @job.id)
    end

    def has_scheduled_execution?
      SolidQueue::ScheduledExecution.exists?(job_id: @job.id)
    end

    def has_ready_execution?
      SolidQueue::ReadyExecution.exists?(job_id: @job.id)
    end

    class << self
      def find(id)
        job = SolidQueue::Job.find(id)
        failed = SolidQueue::FailedExecution.find_by(job_id: id)
        claimed = SolidQueue::ClaimedExecution.find_by(job_id: id)
        new(job, failed_execution: failed, claimed_execution: claimed)
      end

      def all_with_status(status = nil, page: 1, per_page: 25, class_name: nil, queue_name: nil)
        jobs = case status&.to_s
        when "pending"
          pending_jobs
        when "scheduled"
          scheduled_jobs
        when "in_progress"
          in_progress_jobs
        when "failed"
          failed_jobs
        when "blocked"
          blocked_jobs
        when "finished"
          finished_jobs
        else
          all_jobs
        end

        jobs = apply_filters(jobs, class_name: class_name, queue_name: queue_name)
        jobs = jobs.order(created_at: :desc)
        paginate(jobs, page: page, per_page: per_page)
      end

      def apply_filters(scope, class_name: nil, queue_name: nil)
        scope = scope.where(class_name: class_name) if class_name.present?
        scope = scope.where(queue_name: queue_name) if queue_name.present?
        scope
      end

      def search(query, page: 1, per_page: 25)
        jobs = SolidQueue::Job
          .where("class_name LIKE ? OR arguments LIKE ? OR CAST(id AS TEXT) LIKE ?",
                 "%#{query}%", "%#{query}%", "%#{query}%")
          .order(created_at: :desc)

        paginate(jobs, page: page, per_page: per_page)
      end

      private

      def pending_jobs
        SolidQueue::Job.joins(
          "INNER JOIN solid_queue_ready_executions ON solid_queue_ready_executions.job_id = solid_queue_jobs.id"
        )
      end

      def scheduled_jobs
        SolidQueue::Job.joins(
          "INNER JOIN solid_queue_scheduled_executions ON solid_queue_scheduled_executions.job_id = solid_queue_jobs.id"
        )
      end

      def in_progress_jobs
        SolidQueue::Job.joins(
          "INNER JOIN solid_queue_claimed_executions ON solid_queue_claimed_executions.job_id = solid_queue_jobs.id"
        )
      end

      def failed_jobs
        SolidQueue::Job.joins(
          "INNER JOIN solid_queue_failed_executions ON solid_queue_failed_executions.job_id = solid_queue_jobs.id"
        )
      end

      def blocked_jobs
        SolidQueue::Job.joins(
          "INNER JOIN solid_queue_blocked_executions ON solid_queue_blocked_executions.job_id = solid_queue_jobs.id"
        )
      end

      def finished_jobs
        SolidQueue::Job.where.not(finished_at: nil)
      end

      def all_jobs
        SolidQueue::Job.all
      end

      def paginate(scope, page:, per_page:)
        page = [ page.to_i, 1 ].max
        offset = (page - 1) * per_page
        total = scope.count

        jobs = scope.limit(per_page).offset(offset).map { |job| new(job) }
        pagy = OpenStruct.new(
          page: page,
          pages: (total.to_f / per_page).ceil,
          count: total,
          prev: page > 1 ? page - 1 : nil,
          next: page < (total.to_f / per_page).ceil ? page + 1 : nil
        )

        [ pagy, jobs ]
      end
    end
  end
end
