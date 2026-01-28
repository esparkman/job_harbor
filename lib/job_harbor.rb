require "job_harbor/version"
require "job_harbor/configuration"
require "job_harbor/engine"

module JobHarbor
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
