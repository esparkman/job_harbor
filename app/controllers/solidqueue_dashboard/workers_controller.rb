# frozen_string_literal: true

module SolidqueueDashboard
  class WorkersController < ApplicationController
    def index
      @workers = SolidQueue::Process.order(last_heartbeat_at: :desc)
      @active_count = @workers.where("last_heartbeat_at > ?", 5.minutes.ago).count
      @stale_count = @workers.count - @active_count
      set_page_title "Workers"
    end
  end
end
