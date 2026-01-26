# frozen_string_literal: true

module SolidqueueDashboard
  class RecurringTasksController < ApplicationController
    before_action :set_task, only: [ :show, :enqueue_now ]

    def index
      @tasks = SolidQueue::RecurringTask.order(:key)
      set_page_title "Recurring Tasks"
    end

    def show
      @recent_executions = SolidQueue::RecurringExecution
        .where(task_key: @task.key)
        .order(created_at: :desc)
        .limit(20)
      set_page_title "Task: #{@task.key}"
    end

    def enqueue_now
      @task.enqueue(at: Time.current)
      redirect_to recurring_task_path(@task), notice: "Task '#{@task.key}' has been enqueued."
    rescue => e
      redirect_to recurring_task_path(@task), alert: "Failed to enqueue task: #{e.message}"
    end

    private

    def set_task
      @task = SolidQueue::RecurringTask.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to recurring_tasks_path, alert: "Recurring task not found."
    end
  end
end
