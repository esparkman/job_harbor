# frozen_string_literal: true

module SolidqueueDashboard
  class ApplicationComponent < ViewComponent::Base
    include SolidqueueDashboard::Engine.routes.url_helpers

    private

    def sq_config
      SolidqueueDashboard.configuration
    end
  end
end
