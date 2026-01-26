require "solidqueue_dashboard/version"
require "solidqueue_dashboard/configuration"
require "solidqueue_dashboard/engine"

module SolidqueueDashboard
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
