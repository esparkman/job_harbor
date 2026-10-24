module JobHarbor
  class Engine < ::Rails::Engine
    isolate_namespace JobHarbor

    config.after_initialize do
      if !Rails.env.local? && !JobHarbor.configuration.authorize_with_configured?
        Rails.logger.warn "JobHarbor: authorize_with is not configured; the dashboard denies all requests " \
          "outside development and test. Set JobHarbor.configure { |c| c.authorize_with = -> { ... } }."
      end
    end

    initializer "job_harbor.deprecator" do |app|
      app.deprecators[:job_harbor] = JobHarbor.deprecator
    end

    # Sprockets hosts only; Propshaft ignores precompile.
    initializer "job_harbor.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          job_harbor/application.css
        ]
      end
    end
  end
end
