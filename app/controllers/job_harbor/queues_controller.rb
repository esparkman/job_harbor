# frozen_string_literal: true

module JobHarbor
  class QueuesController < ApplicationController
    before_action :set_queue, only: [ :show, :pause, :resume ]

    def index
      @queues = QueueStats.all
      set_page_title "Queues"
    end

    def show
      @page_info, @jobs = JobQuery.new(queue_name: @queue.name).page(params[:page], per_page: sq_config.jobs_per_page)
      set_page_title "Queue: #{@queue.name}"
    end

    def pause
      @queue.pause
      redirect_to queues_path, notice: "Queue '#{@queue.name}' has been paused."
    end

    def resume
      @queue.resume
      redirect_to queues_path, notice: "Queue '#{@queue.name}' has been resumed."
    end

    private

    def set_queue
      @queue = QueueStats.find(params[:name])
      redirect_to queues_path, alert: "Queue not found." unless @queue
    end
  end
end
