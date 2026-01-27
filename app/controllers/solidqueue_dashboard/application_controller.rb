# frozen_string_literal: true

module SolidqueueDashboard
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    before_action :authorize_access

    layout "solidqueue_dashboard/application"

    helper_method :sq_config, :nav_counts

    private

    def authorize_access
      return if SolidqueueDashboard.configuration.authorize(self)

      redirect_to main_app.root_path, alert: "Admin access required."
    end

    def sq_config
      SolidqueueDashboard.configuration
    end

    def set_page_title(title)
      @page_title = title
    end

    def nav_counts
      @nav_counts ||= {
        workers: SolidQueue::Process.where(kind: "Worker").count,
        recurring_tasks: recurring_task_count
      }
    end

    def recurring_task_count
      return 0 unless sq_config.enable_recurring_tasks

      SolidQueue::RecurringTask.count
    rescue
      0
    end
  end
end
