# frozen_string_literal: true

module SolidqueueDashboard
  class DashboardController < ApplicationController
    def index
      @stats = DashboardStats.new
      set_page_title "Dashboard"
    end
  end
end
