# frozen_string_literal: true

module JobHarbor
  class JobsController < ApplicationController
    BULK_BATCH_SIZE = 500

    before_action :set_job, only: [ :show, :retry, :discard ]
    before_action :reject_malformed_filters, only: [ :retry_all, :discard_all ]

    def index
      @status = params[:status]
      @per_page = per_page_param
      @class_name = filter_param(:class_name)
      @queue_name = filter_param(:queue_name)

      @pagy, @jobs = JobPresenter.all_with_status(
        @status,
        page: params[:page],
        per_page: @per_page,
        class_name: @class_name,
        queue_name: @queue_name
      )
      @counts = job_counts
      @bulk_count = bulk_scope(@status)&.count
      @filter_data = filter_data
      set_page_title @status ? "#{@status.titleize} Jobs" : "All Jobs"
    end

    def show
      set_page_title "Job ##{@job.id}"
    end

    def search
      query = params[:q].to_s.strip
      if query.present?
        @per_page = per_page_param
        @pagy, @jobs = JobPresenter.search(query, page: params[:page], per_page: @per_page)
        set_page_title "Search Results"
      else
        redirect_to jobs_path
      end
    end

    def retry
      if @job.can_retry?
        perform_retry(@job)
        redirect_to return_path || job_path(@job), notice: "Job has been queued for retry."
      else
        redirect_to job_path(@job), alert: "This job cannot be retried."
      end
    end

    def discard
      if @job.can_discard? && @job.discard
        redirect_to return_path || jobs_path(status: params[:return_status]), notice: "Job has been discarded."
      else
        redirect_to job_path(@job), alert: "This job cannot be discarded."
      end
    rescue SolidQueue::Execution::UndiscardableError
      redirect_to job_path(@job), alert: "This job cannot be discarded."
    end

    def retry_all
      count = retry_all_jobs(params[:status])
      redirect_to bulk_redirect_path, notice: "#{helpers.pluralize(count, "job")} queued for retry."
    end

    def discard_all
      count = discard_all_jobs(params[:status])
      redirect_to bulk_redirect_path, notice: "#{helpers.pluralize(count, "job")} discarded."
    end

    private

    def set_job
      @job = JobPresenter.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to jobs_path, alert: "Job not found."
    end

    # Only a path inside this engine's mount, so a crafted param can't send the operator elsewhere.
    def return_path
      path = params[:return_to]
      return unless path.is_a?(String) && path.match?(%r{\A/[^\\\s]*\z}) && !path.start_with?("//")

      mount = request.script_name
      return unless path == mount || path.start_with?("#{mount}/", "#{mount}?")
      return if URI.parse(path).path.split("/").include?("..")

      path
    rescue URI::InvalidURIError
      nil
    end

    def per_page_param
      per_page = params[:per_page].to_i
      valid_sizes = JobHarbor::PerPageSelectorComponent::PAGE_SIZES
      valid_sizes.include?(per_page) ? per_page : sq_config.jobs_per_page
    end

    def filter_data
      {
        class_names: SolidQueue::Job.distinct.pluck(:class_name).sort,
        queue_names: SolidQueue::Job.distinct.pluck(:queue_name).sort
      }
    end

    def job_counts
      {
        all: SolidQueue::Job.count,
        pending: SolidQueue::ReadyExecution.count,
        scheduled: SolidQueue::ScheduledExecution.count,
        in_progress: SolidQueue::ClaimedExecution.count,
        failed: SolidQueue::FailedExecution.count,
        blocked: SolidQueue::BlockedExecution.count,
        finished: SolidQueue::Job.where.not(finished_at: nil).count
      }
    end

    def perform_retry(job)
      failed_execution = SolidQueue::FailedExecution.find_by(job_id: job.id)
      return unless failed_execution

      failed_execution.retry
    end

    # Nil for tabs without bulk actions.
    def bulk_scope(status)
      executions = case status
      when "failed" then SolidQueue::FailedExecution
      when "blocked" then SolidQueue::BlockedExecution
      end
      return unless executions

      JobPresenter.apply_filters(
        SolidQueue::Job.where(id: executions.select(:job_id)),
        class_name: filter_param(:class_name),
        queue_name: filter_param(:queue_name)
      )
    end

    def reject_malformed_filters
      head :bad_request unless %i[ class_name queue_name ].all? { |key| params[key].nil? || params[key].is_a?(String) }
    end

    def filter_param(key)
      params[key] if params[key].is_a?(String)
    end

    def bulk_redirect_path
      jobs_path(status: params[:status], class_name: filter_param(:class_name).presence, queue_name: filter_param(:queue_name).presence)
    end

    def retry_all_jobs(status)
      return 0 unless status == "failed"

      bulk_scope(status).in_batches(of: BULK_BATCH_SIZE).sum { |jobs| SolidQueue::FailedExecution.retry_all(jobs) }
    end

    def discard_all_jobs(status)
      scope = bulk_scope(status)
      return 0 unless scope

      executions = status == "failed" ? SolidQueue::FailedExecution : SolidQueue::BlockedExecution
      scope.in_batches(of: BULK_BATCH_SIZE).sum do |jobs|
        ids = jobs.ids
        executions.discard_all_from_jobs(jobs)
        ids.size - SolidQueue::Job.where(id: ids).count
      end
    end
  end
end
