module JobHarbor
  class Engine < ::Rails::Engine
    isolate_namespace JobHarbor

    # Load ViewComponent
    initializer "job_harbor.view_component" do
      ActiveSupport.on_load(:view_component) do
        # Configure ViewComponent for the engine
      end
    end

    # Set up component paths
    initializer "job_harbor.components" do |app|
      if app.config.respond_to?(:view_component)
        app.config.view_component.preview_paths << root.join("app/components")
      end
    end

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
