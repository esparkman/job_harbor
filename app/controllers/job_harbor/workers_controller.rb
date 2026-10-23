# frozen_string_literal: true

module JobHarbor
  class WorkersController < ApplicationController
    def index
      @workers = SolidQueue::Process.order(last_heartbeat_at: :desc)
      @active_count = Processes.alive.count
      @stale_count = @workers.count - @active_count
      set_page_title "Workers"
    end
  end
end
