# frozen_string_literal: true

module SolidqueueDashboard
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    before_action :authorize_access

    layout "solidqueue_dashboard/application"

    helper_method :sq_config

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
  end
end
