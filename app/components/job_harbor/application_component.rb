# frozen_string_literal: true

module JobHarbor
  class ApplicationComponent < ViewComponent::Base
    include JobHarbor::Engine.routes.url_helpers

    private

    def sq_config
      JobHarbor.configuration
    end
  end
end
