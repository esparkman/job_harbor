module JobHarbor
  class Configuration
    attr_accessor :authorize_with,
                  :theme,
                  :primary_color,
                  :jobs_per_page,
                  :enable_recurring_tasks,
                  :enable_real_time_updates,
                  :poll_interval,
                  :enable_failure_stats,
                  :enable_charts,
                  :default_chart_range,
                  :return_to_app_path,
                  :return_to_app_label

    def initialize
      @theme = :dark
      @primary_color = "amber"
      @jobs_per_page = 25
      @enable_recurring_tasks = true
      @enable_real_time_updates = true
      @poll_interval = 5
      @enable_failure_stats = true
      @enable_charts = true
      @default_chart_range = "24h"
      @return_to_app_path = nil
      @return_to_app_label = "Back to App"
    end

    def authorize_with_configured?
      !authorize_with.nil?
    end

    # Unconfigured means open in development and test only.
    def authorize(controller)
      return controller.instance_exec(&authorize_with) if authorize_with_configured?

      Rails.env.local?
    end
  end
end
