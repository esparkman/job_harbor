# frozen_string_literal: true

module JobHarbor
  class QueuesController < ApplicationController
    # Solid Queue's queue_name columns are plain strings; 255 fits every adapter's default string limit.
    MAX_QUEUE_NAME_LENGTH = 255

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

    def pre_pause
      name = params[:name]
      name = name.strip if name.is_a?(String)

      if !name.is_a?(String) || name.empty?
        redirect_to queues_path, alert: "Enter a queue name to pause."
      elsif name.length > MAX_QUEUE_NAME_LENGTH
        redirect_to queues_path, alert: "Queue name must be #{MAX_QUEUE_NAME_LENGTH} characters or fewer."
      else
        queue = QueueStats.new(name)
        already_paused = queue.paused?
        queue.pause
        redirect_to queues_path, notice: "Queue '#{name}' #{already_paused ? "is already paused" : "has been paused"}."
      end
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
