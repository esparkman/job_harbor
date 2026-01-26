module SolidqueueDashboard
  class Engine < ::Rails::Engine
    isolate_namespace SolidqueueDashboard

    # Load ViewComponent
    initializer "solidqueue_dashboard.view_component" do
      ActiveSupport.on_load(:view_component) do
        # Configure ViewComponent for the engine
      end
    end

    # Set up component paths
    initializer "solidqueue_dashboard.components" do |app|
      app.config.view_component.preview_paths << root.join("app/components")
    end

    # Add assets to pipeline
    initializer "solidqueue_dashboard.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          solidqueue_dashboard/application.css
        ]
      end
    end
  end
end
