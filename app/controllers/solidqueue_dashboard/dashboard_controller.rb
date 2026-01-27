# frozen_string_literal: true

module SolidqueueDashboard
  class DashboardController < ApplicationController
    def index
      @stats = DashboardStats.new
      @failure_stats = FailureStats.new.stats if sq_config.enable_failure_stats

      if sq_config.enable_charts
        @chart_range = params[:chart_range] || sq_config.default_chart_range
        @chart_data = ChartData.new(range: @chart_range).series
      end

      set_page_title "Dashboard"
    end
  end
end
