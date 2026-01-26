module SolidqueueDashboard
  class Configuration
    attr_accessor :authorize_with,
                  :theme,
                  :primary_color,
                  :jobs_per_page,
                  :enable_recurring_tasks,
                  :enable_real_time_updates,
                  :poll_interval

    def initialize
      @authorize_with = -> { true }
      @theme = :dark
      @primary_color = "amber"
      @jobs_per_page = 25
      @enable_recurring_tasks = true
      @enable_real_time_updates = true
      @poll_interval = 5
    end

    def authorize(controller)
      controller.instance_exec(&authorize_with)
    end
  end
end
