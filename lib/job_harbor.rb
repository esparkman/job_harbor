require "job_harbor/version"
require "job_harbor/configuration"
require "job_harbor/time_formats"
require "job_harbor/engine"

module JobHarbor
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("1.0", "JobHarbor")
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
