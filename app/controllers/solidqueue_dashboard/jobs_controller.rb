# frozen_string_literal: true

module SolidqueueDashboard
  class JobsController < ApplicationController
    before_action :set_job, only: [ :show, :retry, :discard ]

    def index
      @status = params[:status]
      @per_page = per_page_param
      @class_name = params[:class_name]
      @queue_name = params[:queue_name]

      @pagy, @jobs = JobPresenter.all_with_status(
        @status,
        page: params[:page],
        per_page: @per_page,
        class_name: @class_name,
        queue_name: @queue_name
      )
      @counts = job_counts
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
        redirect_to job_path(@job), notice: "Job has been queued for retry."
      else
        redirect_to job_path(@job), alert: "This job cannot be retried."
      end
    end

    def discard
      if @job.can_discard?
        perform_discard(@job)
        redirect_to jobs_path(status: params[:return_status]), notice: "Job has been discarded."
      else
        redirect_to job_path(@job), alert: "This job cannot be discarded."
      end
    end

    def retry_all
      status = params[:status]
      count = retry_all_jobs(status)
      redirect_to jobs_path(status: status), notice: "#{count} jobs queued for retry."
    end

    def discard_all
      status = params[:status]
      count = discard_all_jobs(status)
      redirect_to jobs_path(status: status), notice: "#{count} jobs discarded."
    end

    private

    def set_job
      @job = JobPresenter.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to jobs_path, alert: "Job not found."
    end

    def per_page_param
      per_page = params[:per_page].to_i
      valid_sizes = SolidqueueDashboard::PerPageSelectorComponent::PAGE_SIZES
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

    def perform_discard(job)
      # Remove from any execution tables
      SolidQueue::FailedExecution.where(job_id: job.id).delete_all
      SolidQueue::BlockedExecution.where(job_id: job.id).delete_all
      SolidQueue::ScheduledExecution.where(job_id: job.id).delete_all
      SolidQueue::ReadyExecution.where(job_id: job.id).delete_all

      # Mark job as finished (discarded)
      SolidQueue::Job.where(id: job.id).update_all(finished_at: Time.current)
    end

    def retry_all_jobs(status)
      return 0 unless status == "failed"

      count = 0
      SolidQueue::FailedExecution.find_each do |fe|
        fe.retry
        count += 1
      end
      count
    end

    def discard_all_jobs(status)
      case status
      when "failed"
        count = SolidQueue::FailedExecution.count
        job_ids = SolidQueue::FailedExecution.pluck(:job_id)
        SolidQueue::FailedExecution.delete_all
        SolidQueue::Job.where(id: job_ids).update_all(finished_at: Time.current)
        count
      when "blocked"
        count = SolidQueue::BlockedExecution.count
        job_ids = SolidQueue::BlockedExecution.pluck(:job_id)
        SolidQueue::BlockedExecution.delete_all
        SolidQueue::Job.where(id: job_ids).update_all(finished_at: Time.current)
        count
      else
        0
      end
    end
  end
end
