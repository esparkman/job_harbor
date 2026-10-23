# frozen_string_literal: true

module JobHarbor
  class RecurringTasksController < ApplicationController
    RECENT_EXECUTIONS_LIMIT = 20

    before_action :set_task, only: [ :show, :enqueue_now ]

    def index
      @tasks = SolidQueue::RecurringTask.order(:key)
      set_page_title "Recurring Tasks"
    end

    def show
      executions = SolidQueue::RecurringExecution.where(task_key: @task.key)
      @executions_count = executions.count
      @last_run_at = executions.maximum(:run_at)
      @recent_executions = executions.order(run_at: :desc).limit(RECENT_EXECUTIONS_LIMIT)
      set_page_title "Task: #{@task.key}"
    end

    def enqueue_now
      if enqueued?(at: Time.current)
        redirect_to recurring_task_path(@task), notice: "Task '#{@task.key}' has been enqueued."
      else
        redirect_to recurring_task_path(@task),
          alert: "Task '#{@task.key}' was not enqueued. It may have just run, or the job refused to enqueue; check the logs."
      end
    end

    private

    # SQ 1.0.x records a halted job with a nil job_id; the NotNullViolation rolls back.
    def enqueued?(at:)
      job = @task.enqueue(at: at)
      job.present? && job.successfully_enqueued?
    rescue ActiveRecord::NotNullViolation => error
      Rails.error.report(error, handled: true)
      false
    end

    def set_task
      @task = SolidQueue::RecurringTask.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to recurring_tasks_path, alert: "Recurring task not found."
    end
  end
end
