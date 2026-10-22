module JobHarbor
  class Engine < ::Rails::Engine
    isolate_namespace JobHarbor

    # Add assets to pipeline
    initializer "job_harbor.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          job_harbor/application.css
        ]
      end
    end
  end
end
