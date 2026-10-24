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

    attr_reader :filter_parameters

    def initialize
      @theme = :dark
      @primary_color = "amber"
      @jobs_per_page = 25
      @enable_recurring_tasks = true
      @enable_real_time_updates = true
      @poll_interval = 30
      @enable_failure_stats = true
      @enable_charts = true
      @default_chart_range = "24h"
      @return_to_app_path = nil
      @return_to_app_label = "Back to App"
      @filter_parameters = nil
    end

    FILTER_PATTERN_TYPES = [ String, Symbol, Regexp, Proc ].freeze

    # nil follows the host app's list, an Array of strings, symbols, regexps and procs replaces it, false shows raw values.
    # Anything else raises: a stray `true` or `[true]` would otherwise mask nothing while looking protected.
    def filter_parameters=(value)
      unless value.nil? || value == false || (value.is_a?(Array) && value.all? { |pattern| FILTER_PATTERN_TYPES.any? { |type| type === pattern } })
        raise ArgumentError,
          "config.filter_parameters must be nil, false or an Array of Strings, Symbols, Regexps and Procs, got #{value.inspect}"
      end

      @filter_parameters = value
    end

    # An empty list masks nothing, so it counts as off.
    def filtering_parameters?
      filter_parameters != false && filter_parameters != []
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
